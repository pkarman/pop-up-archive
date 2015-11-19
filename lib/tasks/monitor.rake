require 'csv'
require 'time'

namespace :monitor do
  desc "updating feeds"
  task :feed, [:url, :collection_id, :oldest_entry] => [:environment] do |t, args|
    puts "Scheduling new feed check: #{args.url}"
    account_holder = Collection.find(args.collection_id).billable_to
    
    if account_holder.is_over_monthly_limit? 
      puts "Cannot complete for #{args}. Over usage limit warning!"
      next
    end
        
    if ENV['NOW']
      FeedPopUp.update_from_feed(args.url, args.collection_id, ENV['DRY_RUN'], (args.oldest_entry || ENV['OLDEST_ENTRY']))
      p "process feedpopup"
    else
      FeedUpdateWorker.perform_async(args.url, args.collection_id, (args.oldest_entry || ENV['OLDEST_ENTRY']))
      p "process feedupdate"
    end
    puts "done."

  end

  desc "check transcripts for gaps"
  task transcript: [:environment] do

    Transcript.unscoped.where(:transcriber_id => 2).order('created_at desc').each do |tr|
      starts = []
      tr.timed_texts.each do |tt| 
        starts.push tt.start_time
      end
      if starts.size == 0
        puts "#{tr.id} #{tr.created_at} https://www.popuparchive.com/tplayer/#{tr.audio_file_id} << empty"
        next
      end
      starts.each_with_index do |st,idx| 
        next if idx == 0
        prev_start = starts[idx-1]
        if st - prev_start > 60.0
          gap = st - prev_start
          st_hms = Time.at(st).getgm.strftime('%H:%M:%S')
          prev_hms = Time.at(prev_start).getgm.strftime('%H:%M:%S')
          puts "#{tr.id} #{tr.created_at} https://www.popuparchive.com/tplayer/#{tr.audio_file_id} #{prev_hms} -> #{st_hms} #{gap}"
        end
      end
    end
  end

  desc "check for transcripts edited in the past X hours"
  task new_transcript_edits: [:environment] do
    edited = Transcript.joins(:timed_texts).where("timed_texts.updated_at > ?", 24.hours.ago).where("timed_texts.updated_at > timed_texts.created_at")
    puts edited.length.to_s + " were edited in the last 24 hours."
  end

  desc "delete failed uploads from database"
  task :remove_failed_uploads, [:date] => [:environment] do |t, args| 
    p args
    all = Tasks::UploadTask.where("status!=?", "complete").select(:owner_id, :extras)
    upload_not_complete_files = []
    all.each do |task|
        
      if AudioFile.exists?(task.owner_id)
        file = AudioFile.find(task.owner_id) 
        upload_not_complete_files << file.id if !file.is_uploaded?
      end 
    end
        
    p upload_not_complete_files.count
    upload_not_complete_files.each do |id|
      if AudioFile.exists?(id) 
        f = AudioFile.find(id)
        if i=f.item
          if ((i.audio_files.pluck(:id) - upload_not_complete_files).empty?) && (i.audio_files.count > 1)
            deletable = i
          elsif i.audio_files.count > 1
            deletable = f
          elsif i.audio_files.count == 1
            deletable = i  
          end
          time = DateTime.parse(args.date)  
          if f.created_at < time
            puts deletable.id
            puts deletable.class.name
            begin 
              deletable.destroy 
            rescue => e
              puts e
            end
          end
        end
      end
    end
  end  

   #[34159, 34183, 34581] 
  desc "generate basic transcripts for audio files with no transcripts"
  task :create_missing_transcripts, [:ids] => [:environment] do |t, args|
    ids = args.ids.split(' ').map(&:to_i)
    p ids
    ids.each do |id|
      file = AudioFile.find(id)
      user = User.find(file.user_id)
      if user.id == file.user_id
        file.reprocess_as_basic_transcript(user, 'ts_all')
      end  
    end
  end 
  
  desc "generate copy to s3 tasks for AudioFiles with failed tasks" 
  task :run_copy_to_s3_tasks, [:date] => [:environment] do |t, args|
    time = DateTime.parse(args.date) 
    files = AudioFile.where("created_at < ?", time)
    ai=[]
    neither=[]
    ai_not_copied = []
    leftovers = []
    files.each do |file|
      if (file != nil) && (i=file.item || c=file.collection) && (file.url('mp3') != nil) 
        if (file.url('mp3').exclude? 'cloudfront') && (file.copy_media? == true)
          if (file.tasks.any?{ |t| t.type == "Tasks::CopyToS3Task" && t.status == "complete"}) && (file.url('mp3').include? "/archive.org/")
            proper_storage = file.tasks.where(type: "Tasks::CopyToS3Task").last.storage
            file.storage_configuration = proper_storage 
            file.save
          elsif (file.url('mp3').exclude? "/archive.org/") && (file.storage_configuration != nil) && (file.storage_configuration.provider != "AWS") 
            file.process_file
            file.start_copy_to_s3_job
          elsif file.url('mp3').include? "/archive.org/"
            file.start_copy_to_s3_job
          end 
        end       
      end
      
    end

  end        
  
end 

