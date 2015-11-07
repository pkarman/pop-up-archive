require 'csv'

namespace :monitor do
  desc "updating feeds"
  task :feed, [:url, :collection_id] => [:environment] do |t, args|
    puts "Scheduling new feed check: #{args.url}"
    process_feed = true
    account_holder = Collection.find(args.collection_id).creator.entity.id
    process_feed = false if User.over_limits.exists?(account_holder)
        
    if process_feed == true
      if ENV['NOW']
        FeedPopUp.update_from_feed(args.url, args.collection_id, ENV['DRY_RUN'], ENV['OLDEST_ENTRY'])
      else
        FeedUpdateWorker.perform_async(args.url, args.collection_id, ENV['OLDEST_ENTRY'])
      end
      puts "done."
    else
      puts "Cannot complete for #{args}. Over usage limit warning!"
    end
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
        user_combo = {}
             
        if file != nil 
          user_combo["audio_id"] = file.id
          user_combo["name"] = user_email
          user_combo["date_created"] = file.created_at
        end
        upload_not_complete_files<<user_combo
      end           
    end
    destroy_now =[]
    upload_not_complete_files.each do |i|
      if AudioFile.exists?(i["audio_id"]) 
        f = AudioFile.find(i["audio_id"])
          #print deleted files to console
          if f.created_at < Time.new(2013, 11, 15)
            destroy_now << f
            # AudioFile.destroy(f)
          end
      end
    end
    p destroy_now.count
    p destroy_now
    file = "../Desktop/destroy_now.csv"
    #This outputs list of audiofiles with failed upload tasks.
    CSV.open(file, 'w') do |writer|
      upload_not_complete_files.each do |i|
          writer << [i["audio_id"], i["name"], i["date_created"], "www.popuparchive.com/collections/#{i['collection_id']}/items/#{i['item_id']}"] 
        end
      end
    # end
  end
    
  desc "generate transcripts for audio files with no transcripts"
  task create_missing_transcripts: [:environment] do
    all_files = AudioFile.where("duration>?", 5).select(:id, :created_at, :user_id, :item_id, :transcript, :original_file_url)
    collect_files = []
    all_files.each do |f|
      if f.needs_transcript?
        #check IA for those not uploaded
        if (f.has_attribute?("original_file_url")) && (f.original_file_url != nil)
          file_hash = {}
          file_found=FileCleanupWorker.find_file(f.id)
          file_hash["plays"] = "yes : 200" if file_found == 200
          file_hash["plays"] = "check, 403 forbidden" if file_found == 403
          file_hash["plays"] = "no : #{file_found}" if file_found == 404 || 401
          # begin
          #   file_found=HTTParty.head(f.original_file_url, follow_redirects: true, maintain_method_across_redirects: true, limit: 15)
          #   case file_found.code
          #     when 200
          #       puts "Found #{f.id}"
          #       file_hash["plays"] = "yes : 200"
          #       # f.process_file
          #     when 403
          #       puts "Forbidden"
          #       file_hash["plays"] = "check, 403 forbidden"
          #     when 404 || 401
          #       puts "Not found #{response.code}: #{f.id} #{f.original_file_url}"
          #       file_hash["plays"] = "no : #{file_found}"
          #     end
          # rescue => e
          #   p "unknown response"
          # end
          file_hash["audio_id"] = f.id 
          file_hash["created_at"] = f .created_at
          
          if Item.exists?(f.item_id)
            item = Item.find(f.item_id)
            if Collection.exists?(item.collection_id)
              col_id = item.collection_id
              file_hash["url"] =  "www.popuparchive.com/collections/#{col_id}/items/#{item.id}"
            end
          end
        
          if User.exists?(f.user_id)
            u = User.find(f.user_id)
            file_hash["file_owner"] = u.entity.name
            if u.plan.has_premium_transcripts?
              file_hash["has_premium"] = "Premium"
            else  
              file_hash["has_premium"] = "Basic"
            end
          else
            file_hash["file_owner"] = nil
            file_hash["has_premium"] = "none"
          end
          collect_files << file_hash
        
        #for uploaded files with no transcripts
        else 
          uploaded = false
          if f.is_uploaded?
            uploaded = true
          end
          if uploaded == true
            file_hash = {} 
            file_hash["audio_id"] = f.id 
            file_hash["created_at"] = f.created_at
            file_hash["plays"] = "manual check"
            if Item.exists?(f.item_id)
              item = Item.find(f.item_id)
              if Collection.exists?(item.collection_id)
                col_id = item.collection_id
                file_hash["url"] =  "www.popuparchive.com/collections/#{col_id}/items/#{item.id}"
              end
            end
            if User.exists?(f.user_id)
              u = User.find(f.user_id)
              file_hash["file_owner"] = u.entity.name
              if u.plan.has_premium_transcripts?
                file_hash["has_premium"] = "Premium"
              else 
                file_hash["has_premium"] = "none"
              end
            else 
              file_hash["file_owner"] = nil
              file_hash["has_premium"] = "none"
            end
            #f.process_file
            collect_files << file_hash
          end
        end
      end          
    end
    p collect_files
    p collect_files.count
    
    file = "../Desktop/transcripts.csv"

    CSV.open(file, 'w') do |writer|
      writer << ["AudioFile ID", "Date Created", "Owner", "Transcript Type", "url", "found/plays"]
      collect_files.each do |i|
          writer << [i["audio_id"], i["created_at"], i["file_owner"], i["has_premium"], i["url"], i["plays"]] 
      end
    end
  end
end 

