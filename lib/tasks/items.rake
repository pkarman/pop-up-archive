namespace :items do

  desc "align Item.is_public with parent Collection"
  task check_public: [:environment] do
    verbose = ENV['VERBOSE'] || false
    dry_run = ENV['DRY_RUN'] || false

    Item.find_in_batches do |itemgrp|
      itemgrp.each do |item|
        if item.is_public != item.collection.items_visible_by_default
          verbose and puts "Item.find(#{item.id}) is_public mismatch"
          next if dry_run
          item.is_public = item.collection.items_visible_by_default
          item.save!
        end
      end
    end
  end

  desc "identify (and optionally cleanup) duplicate items"
  task check_dupes: [:environment] do
    verbose = ENV['VERBOSE'] || false
    dry_run = ENV['DRY_RUN'] || false

    by_title = {}
    Item.find_in_batches do |itemgrp|
      itemgrp.each do |item|
        k = item.title + ':' + item.collection_id.to_s + ':' + item.date_broadcast.to_s
        if by_title.has_key?(k)
          by_title[k][:count] += 1
          by_title[k][:ids].push item.id
        else
          by_title[k] = { :count => 1, :ids => [ item.id ] }
        end
      end
    end

    by_title.each do |key, value|
      next unless value[:count] > 1
      verbose and puts "Dupe: #{key} #{value.inspect}"

      # keep (the first) with premium transcript
      keeper = nil
      value[:ids].each do |item_id|
        next if keeper
        item = Item.find item_id
        has_premium = false
        item.audio_files.each do |af|
          af.transcripts_alone.each do |t|
            if t.is_premium?
              has_premium = true
            end
          end
        end
        keeper = item_id if has_premium
      end

      # no keeper? keep the first one
      keeper ||= value[:ids].shift

      verbose and puts "  keep #{keeper}"
      next if dry_run
      
      # for others, flag all transcripts as not billable,
      # and then soft-delete the item
      value[:ids].each do |item_id|
        next if item_id == keeper
        item = Item.find item_id
        item.transcripts.each do |tr|
          tr.is_billable = false
          tr.save!
        end
        item.destroy
      end

    end

  end

end
