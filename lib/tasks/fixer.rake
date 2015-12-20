require 'pp'

namespace :fixer do

#########################################################################################################
  desc "check fixer status mismatches"
  task check: [:environment] do

    verbose = ENV['VERBOSE']
    debug   = ENV['DEBUG']
    limit   = ENV['LIMIT']
    ok_to_recover = ENV['RECOVER']
    recover_types = Hash[ ENV['RECOVER_TYPES'] ? ENV['RECOVER_TYPES'].split(/\ *,\ */).map{|t| [t, true]} : [] ]
    debug and pp recover_types.inspect
    puts "Finding all tasks with status mismatch..."
    puts "Will try to recover these types: #{ recover_types.keys.inspect }"
    mismatched_tasks = Task.get_mismatched_status('working')
    mismatched_report = Hash.new{ |h,k| h[k] = 0 }
    mismatched_tasks.each do |task|
      mismatched_report[task.type] += 1
      if limit and limit.to_i <= mismatched_report[task.type]
        debug and puts "Limit #{limit} reached for #{task.type}. Skipping eval of task #{task.id}"
        next
      end
      debug and puts "Task #{task.type} #{task.id} has status '#{task.status}' with results: " + task.results.inspect
      if recover_types.has_key?(task.type) and ok_to_recover
        verbose and puts "Calling #{task.type}.find(#{task.id}).recover!"
        task.recover!
        verbose and puts "#{task.type}.find(#{task.id}) new status == #{task.status}"
        mismatched_report[task.status] += 1
      end
    end

    puts "These tasks with mismatched status were found:"
    pp mismatched_report
  end

#########################################################################################################
  desc "nudge unfinished tasks toward the finish line"
  task nudge: [:environment] do

    verbose = ENV['VERBOSE']
    debug   = ENV['DEBUG']
    limit   = ENV['LIMIT']
    ok_to_recover = ENV['RECOVER']
    recover_types = Hash[ ENV['RECOVER_TYPES'] ? ENV['RECOVER_TYPES'].split(/\ *,\ */).map{|t| [t, true]} : [] ]
    report     = Hash.new{ |h,k| h[k] = 0 }
    unfinished = Task.incomplete
    verbose and puts "Nudging #{unfinished.count} unfinished tasks"
    verbose and puts "Will try to recover these types: #{ recover_types.keys.inspect }"
    unfinished.find_in_batches do |taskgroup|
      taskgroup.each do |task|
        if limit and limit.to_i <= report[task.type]
          next
        end

        debug and puts "Task.find(#{task.id}) -> #{task.type}"
        report[task.type] += 1

        if task.stuck?
          report[task.type+'-stuck'] += 1
          if ok_to_recover and recover_types.has_key?(task.type)
            begin
              task.recover!
              task.owner.check_tasks if task.owner
              report[task.type+'-recovered'] += 1
            rescue Exceptions::PrivateFileNotFound => err
              STDERR.puts err  # warn and continue
            rescue => err
              raise err # re-throw
            end
          end
        end
      end
    end

    verbose and pp report

  end

#########################################################################################################
  desc "nudge unfinished uploads toward the finish line"
  task nudge_uploads: [:environment] do

    verbose = ENV['VERBOSE']
    debug   = ENV['DEBUG']
    limit   = ENV['LIMIT']
    recover = ENV['RECOVER']

    report     = Hash.new{ |h,k| h[k] = 0 }
    unfinished = Task.upload.incomplete
    verbose and puts "Nudging #{unfinished.count} unfinished Upload tasks"
 
    unfinished.find_in_batches do |taskgroup|
      taskgroup.each do |task|
        if limit and limit.to_i <= report[task.type]
          next
        end 

        debug and puts "Task::UploadTask.find(#{task.id})"
        report[:incomplete] += 1

        if task.num_chunks == 0
          report[:zero_chunks] += 1
        end

        if task.num_chunks > 0 and task.num_chunks != task.chunks_uploaded.size
          report[:chunks_unfinished] += 1
        end

        if task.stuck?
          report[:stuck] += 1
          task.recover! if recover
        end 
      end 
    end 

    verbose and pp report

  end

#########################################################################################################
  desc "set duration from any complete transcoding"
  task set_duration: [:environment] do

    print "Finding all audio_file records with nil duration... "
    affected = AudioFile.where('duration is null')
    puts "found #{affected.count}"
    fixed = 0
    affected.find_in_batches do |afgroup|
      afgroup.each do |af|
        af.tasks.each do |task|
          if task.type == "Tasks::TranscodeTask" and task.status == 'complete'
            if task.results and task.results['info'] and task.results['info']['length']
              puts "audio #{af.id} has nil duration, but task #{task.identifier}:#{task.id} has length #{task.results['info']['length']}"
              af.update_attribute(:duration, task.results['info']['length'].to_i)
              fixed += 1
            end
          end
        end
      end
    end
    puts "Updated #{fixed} audio_files"

  end

#########################################################################################################
  desc "unfinished uploads"
  task unfinished_uploads: [:environment] do
    print "Finding all audio_file records with nil duration... "
    affected = AudioFile.where('duration is null')
    puts "found #{affected.count}"
    affected.find_in_batches do |afgroup|
      afgroup.each do |af|
        if af.has_failed_upload?
          puts "AudioFile.find(#{af.id}) has failed upload. Status==#{af.current_status}"
        end
      end
    end
  end

#########################################################################################################
  desc "speechmatics sanity check"
  task speechmatics_poll: [:environment] do
    # No tasks are recovered by default, since that means notifying the user on success,
    # which we might not want to do in testing/dev. Set RECOVER env var to trigger task.recover!
    ok_to_recover = ENV['RECOVER']
 
    # find all status=created older than N hours
    # and verify they exist at SM. If not, cancel them.
    ago = Task.work_window
    sm_tasks = Task.speechmatics_transcribe.incomplete.where('created_at < ?', ago)
    sm_tasks_count = sm_tasks.count
    puts "Found #{sm_tasks_count} unfinished Speechmatics tasks older than #{ago}"

    report = {'cancelled, no job_id' => 0, 'missing job_id' => 0, 'No SM job found for job_id' => 0, 'recovered' => 0}

    # fetch all SM jobs at once to save HTTP overhead.
    # TODO ask them to implement sorting, searching, paging.
    sm = Speechmatics::Client.new({ :request => { :timeout => 120 } })
    sm_jobs = sm.user.jobs.list.jobs
    # create lookup hash by job id
    sm_jobs_lookup = Hash[ sm_jobs.map{ |smjob| [smjob['id'].to_s, smjob] } ]
    sm_tasks.find_in_batches do |taskgroup|
      taskgroup.each do |task|
        # if we don't have a job_id then it never was created at SM
        if !task.extras['job_id']
          puts "Task.find(#{task.id}) has no job_id: #{task.inspect}"

          # if not recovering, log it and skip to next
          if !ok_to_recover
            report['missing job_id'] += 1
            next
          end

          begin
            task.recover!  # should cancel it with err msg if can't reverse lookup job_id
          rescue Exception => err
            puts "Task.find(#{task.id}).recover failed with #{err}"
            next
          end

          if task.status == "cancelled"
            report['cancelled, no job_id'] += 1
          elsif task.status == "complete" || task.status == "working"
            report['recovered'] += 1
          else
            puts "Called Task.find(#{task.id}).recover! and ended with status '#{task.status}'"
          end
          next
        end

        # lookup SM status
        sm_job = sm_jobs_lookup[task.extras['job_id']]
        if !sm_job
          task.extras[:error] = "No SM job found for job_id"
          task.cancel!
          puts "No SM job found for task: #{task.inspect}"
          report['No SM job found for job_id'] += 1
          next
        end

        puts "Task.find(#{task.id}) looks like this at SM: #{sm_job.inspect}"
        if ok_to_recover
          task.recover! && report['recovered'] += 1
        end
         
      end
    end

    report.keys.each do |k|
      puts "#{k} => #{report[k].to_s}"
    end

  end

#########################################################################################################
  desc "check for audio with no transcript and (optionally) create it"
  task transcript_check: [:environment] do

    ok_to_recover = ENV['RECOVER']
    verbose       = ENV['VERBOSE']

    AudioFile.where('duration is not null').where('id not in (select audio_file_id from transcripts)').find_in_batches do |afgroup|
      afgroup.each do |af|

        if !af.has_file? && af.original_file_url.blank?
          next  # can't do anything
        end

        if af.needs_transcript?
          verbose and puts "AudioFile.find(#{af.id}) needs any transcript"
          ok_to_recover and af.check_tasks
        end

      end
    end 

  end # task

#########################################################################################################
  desc "fix broken audio file links"
  task sc_fix: [:environment] do
    filename = ENV['FILE'] or raise "FILE required"
    File.readlines(filename).each do |line|
      item_id = line.chomp
      item = Item.find item_id
      item.audio_files.each do |af|
        if af.stuck?
          puts '='*80
          puts "af #{af.id} #{af.current_status}"
          puts "token=#{af.item.token}"
          puts "url=#{af.url}"
          puts "dest_path=#{af.destination_path}"
          puts "process_file_url=#{af.process_file_url}"
          copy_url = URI(af.tasks.copy.valid.first.identifier)
          puts "actual=#{copy_url}"
          bucket = copy_url.host
          real_token = bucket+'/'+copy_url.path.split(/\//)[1]
          puts "real_token=#{real_token}"
          cmd = "aws ls #{real_token}"
          puts "#{cmd}"
          #system(cmd)
          aws_info = `#{cmd}`.split("\n")
          orig_path = nil
          aws_info.grep(/^\|/).slice(2..-1).each do |awsi|
            aws_parts = awsi.split(/\ *\|\ */)
            puts "aws_parts=#{aws_parts.inspect}"
            orig_path = aws_parts[6]
            if orig_path.match(/\S/)
              orig_filename = File.basename(orig_path)
              copier = "aws copy #{bucket}/#{af.item.token}/#{orig_filename} /#{bucket}/#{orig_path}"
              deleter = "aws rm /#{bucket}/#{orig_path}"
              puts "copier=#{copier}"
              puts "deleter=#{deleter}"
              system(copier) && system(deleter)
            end
          end
          #resp = Utils::head_resp(af.url, 1)
          #puts resp.inspect
        end
      end
    end
  end

#########################################################################################################
## migration to fixer.popuparchive.com

  desc "migrate storage_id on items and audio_files"
  task migrate_storage_ids: [:environment] do
    # my dev env tests show this performs at about 100 rows/sec
    Item.where(storage_id: nil).find_in_batches do |items|
      items.each do |item|
        item.update_columns(storage_id: item.collection.default_storage_id)
      end
    end
    AudioFile.where(storage_id: nil).find_in_batches do |afs|
      afs.each do |af|
        next unless af.item
        af.update_columns(storage_id: af.item.storage_id)
      end
    end
    ImageFile.where(storage_id: nil).find_in_batches do |imgs|
      imgs.each do |imgf|
        next unless imgf.imageable
        imgf.update_columns(storage_id: imgf.imageable.storage.id)
      end 
    end
  end

  desc "migrate collection storage ids"
  task migrate_collection_storage_ids: [:environment] do
  # **********************************************************************************************
  # WARNING: should only run this once per environment since it is destructive and not idempotent.
  # MUST run AFTER migrate_storage_ids
  # **********************************************************************************************
  # we want to assign all existing collections to new storage_configurations
  # so that any new items/audio_files added to those collections will point at
  # the new s3 location.
  
  # first we create some new StorageConfiguration objects pointing at new AWS location.
  aws_private_store = StorageConfiguration.create(provider: 'AWS', key: ENV['AWS_ACCESS_KEY'], secret: ENV['AWS_SECRET_ACCESS_KEY'], is_public: false, bucket: ENV['AWS_BUCKET'])
  aws_public_store = StorageConfiguration.create(provider: 'AWS', key: ENV['AWS_ACCESS_KEY'], secret: ENV['AWS_SECRET_ACCESS_KEY'], is_public: false, bucket: ENV['AWS_BUCKET'])

  # second, iterate over all collections and change any whose storage is currently AWS to a new config
    Collection.find_in_batches do |colls|
      colls.each do |coll|
        next unless coll.default_storage.provider == 'AWS'
        if coll.default_storage.is_public
          coll.default_storage_id = aws_public_store.id
        else
          coll.default_storage_id = aws_private_store.id
        end
        coll.save!
      end
    end
  end

  desc "run all fixer.popuparchive.com migrations"
  task pua_migrate: [:environment] do
    Rake::Task["fixer:migrate_storage_ids"].invoke
    Rake::Task["fixer:migrate_storage_ids"].reenable
    Rake::Task["fixer:migrate_collection_storage_ids"].invoke
    Rake::Task["fixer:migrate_collection_storage_ids"].reenable
  end


  desc "Copy all IA mp3 files to S3"
  task ia_mp3_copy: [:environment] do
    AudioFile.find_in_batches do |afs|
      afs.each do |af|
        next unless af.storage && af.storage.automatic_transcode?
        af.start_copy_to_s3_job
      end
    end
  end

  desc "Copy all IA ogg files to S3"
  task ia_ogg_copy: [:environment] do
    Task.where(type: "Tasks::CopyToS3Task").each do |t|
      t.identifier = "copy_mp3_to_s3"
      t.save
    end
    AudioFile.find_in_batches do |afs|
      afs.each do |af|
        next unless af.storage && af.storage.automatic_transcode?
        af.start_copy_to_s3_job
      end
    end
  end

end

