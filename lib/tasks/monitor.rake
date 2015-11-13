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
        file = nil if file.is_uploaded?
      end 
      upload_not_complete_files << file.id if file != nil
    end
        
    a = AudioFile.where(status_code: "G").pluck(:id)
    combo = a + upload_not_complete_files
    uniques = combo.inject([]) { |result,h| result << h unless result.include?(h); result } 
    p uniques.count
    uniques.each do |i|
      if AudioFile.exists?(i) 
        f = AudioFile.find(i)
        if Item.exists?(f.item_id)
          i = Item.find(f.item_id)
          deletable = i if i.audio_files.count == 1
          deletable = f if i.audio_files.count > 1
          time = DateTime.parse(args.since_date)  
          if f.created_at < time
            puts deletable.id
            puts deletable.class.name
            deletable.destroy 
          end
        end
      end
    end
  end  
end