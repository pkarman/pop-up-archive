require 'csv'
require 'time'

namespace :monitor do
  desc "updating feeds"
  task :feed, [:url, :collection_id, :oldest_entry] => [:environment] do |t, args|
    puts "Scheduling new feed check: #{args.url}"
    account_holder = Collection.find(args.collection_id).creator.entity
    
    if account_holder.is_over_monthly_limit? 
      puts "Cannot complete for #{args}. Over usage limit warning!"
      next
    end
        
    if ENV['NOW']
      FeedPopUp.update_from_feed(args.url, args.collection_id, ENV['DRY_RUN'], (args.oldest_entry || ENV['OLDEST_ENTRY']))
    else
      FeedUpdateWorker.perform_async(args.url, args.collection_id, (args.oldest_entry || ENV['OLDEST_ENTRY']))
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
  task :remove_failed_uploads, [:since_date] => [:environment] do |t, args| 
    p args
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
        
    a = AudioFile.where(status_code: "G")
    with_owner=[]
    
    a.each do |f|
            
      if User.exists?(f.user_id) 
        owner = User.find(f.user_id).email
        user_combo={}
        user_combo["audio_id"] = f.id
        user_combo["name"] = owner
        user_combo["date_created"] = f.created_at
        with_owner << user_combo
      end
    end
    combo = with_owner + upload_not_complete_files
    uniques = combo.inject([]) { |result,h| result << h unless result.include?(h); result } 
    uniques.each do |i|
      if AudioFile.exists?(i["audio_id"]) 
        f = AudioFile.find(i["audio_id"])
        if Item.exists?(f.item)
        i = f.item
        time = DateTime.parse(args.since_date)  
        if f.created_at < time
          puts i.title
          puts i.id 
          i.destroy 
        end
      end
    end
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
          # f.process_file if file_found == 200
          
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

