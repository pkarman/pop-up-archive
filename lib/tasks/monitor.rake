require 'csv'

namespace :monitor do
  desc "updating feeds"
  task :feed, [:url, :collection_id] => [:environment] do |t, args|
    puts "Scheduling new feed check: "+args.url
    if ENV['NOW']
      FeedPopUp.update_from_feed(args.url, args.collection_id, ENV['DRY_RUN'], ENV['OLDEST_ENTRY'])
    else
      FeedUpdateWorker.perform_async(args.url, args.collection_id, ENV['OLDEST_ENTRY'])
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
  task remove_failed_uploads: [:environment] do
    all = Tasks::UploadTask.where("status!=?", "complete").select(:owner_id, :extras)
    upload_not_complete_files = []
    all.each do |task|
        
      if AudioFile.exists?(task.owner_id)
        file = AudioFile.find(task.owner_id) 
        file_tasks = file.tasks.select(:type, :status)
        count = 0
        file_tasks.each do |task_item|
          if task_item.type == "Tasks::UploadTask"
            count += 1
            file = nil if count > 1 && task_item.status == "complete"
          elsif task_item.type != "Tasks::UploadTask" && task_item.status == "complete"
            file = nil
          end 
        end  
      end 
      if User.exists?(task.extras["user_id"])
        user_email = User.find(task.extras["user_id"]).email
        user_combo = Hash.new {|h,k| h[k] = ''}
             
        if file != nil 
          user_combo[file.id] = {}
          user_combo[file.id]["audio_id"] = file.id
          user_combo[file.id]["name"] = user_email
          user_combo[file.id]["date_created"] = file.created_at
        end
        upload_not_complete_files<<user_combo
      end           
    end
        
    a = AudioFile.where(status_code: "G")
        # .where("created_at>?", "11/15/2013")
    with_owner=[]
    
    a.each do |f|
            
      if User.exists?(f.user_id) 
        owner = User.find(f.user_id).email
        user_combo={}
        user_combo[f.id] = {}
        user_combo[f.id]["audio_id"] = f.id
        user_combo[f.id]["name"] = owner
        user_combo[f.id]["date_created"] = f.created_at
        with_owner << user_combo
      end
    end
    combo = with_owner + upload_not_complete_files
    uniques = combo.inject([]) { |result,h| result << h unless result.include?(h); result } 
    uniques.each do |key,value|
      key.each do |k,v|
        if AudioFile.exists?(v["audio_id"]) 
          f = AudioFile.find(v["audio_id"])
          #change time in new Time object to delete newer files
          if f.created_at < Time.new(2013, 11, 15)
            #uncomment next line to delete failed Uploads
            # AudioFile.destroy(f)
            puts f
          end
        end
      end
    end
    file = "../Desktop/output_files_users_empty.csv"
    p uniques.count
    #This outputs list of audiofiles with failed upload tasks or with "G" status, with user emails. 
    #Set specific time constraints for deletion on line 115.
    CSV.open(file, 'w') do |writer|
      uniques.each do |i|
        i.each do |key, value|
          writer << [value["audio_id"], value["name"], value["date_created"], "www.popuparchive.com/collections/#{value['collection_id']}/items/#{value['item_id']}"] 
        end
      end
    end
  end
end