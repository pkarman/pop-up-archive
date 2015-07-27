require 'pp'

namespace :s3migrate do

  desc "Copy all Items from PRX S3 bucket to PUA bucket"
  task :all_items => [:environment] do
    verbose = ENV['VERBOSE']
    Item.find_in_batches do |items|
      items.each do |item|
        next if item.storage.key == ENV['AWS_ACCESS_KEY_ID']
        copy_item(item)
      end
    end
  end

  desc "Copy all Collection images from PRX S3 bucket to PUA bucket"
  task :all_collection_images => [:environment] do
    verbose = ENV['VERBOSE']
    Collection.find_in_batches do |colls|
      colls.each do |coll|
        coll.image_files.each do |imgf|
          next if imgf.storage.key == ENV['AWS_ACCESS_KEY_ID']
          # NOTE this will copy multiple images in one go,
          # but we want to update storage config for all of them,
          # so since the assets are small, just re-copy each time.
          # edge case.
          if copy_bucket_dir(coll.token, imgf.storage.bucket, verbose)
            puts "Copy ImageFile #{imgf.id} ok"
            storage        = imgf.storage
            storage.key    = ENV['AWS_ACCESS_KEY_ID']
            storage.secret = ENV['AWS_SECRET_ACCESS_KEY']
            storage.bucket = ENV['AWS_BUCKET']
            storage.save!
          else
            puts "Copy ImageFile #{imgf.id} failed"
          end
        end
      end
    end
  end

  desc "Copy single Item contents from PRX S3 bucket to PUA bucket"
  task :item, [:item_id] => [:environment] do |t, args|
    verbose = ENV['VERBOSE']
    item = Item.find(args.item_id.to_i)
    copy_item(item)
  end

  def copy_item(item)
    verbose = ENV['VERBOSE']
    if item.storage.key == ENV['AWS_ACCESS_KEY_ID']
      raise "Item #{item.id} already configured to use PUA storage"
    end 
    if copy_bucket_dir(item.token, item.storage.bucket, verbose)
      puts "Copy for item #{item.id} ok"
      # update storage config
      storage        = item.storage
      storage.key    = ENV['AWS_ACCESS_KEY_ID']
      storage.secret = ENV['AWS_SECRET_ACCESS_KEY']
      storage.bucket = ENV['AWS_BUCKET']
      storage.save!
    else
      puts "Copy for item #{item.id} failed"
    end
  end

  # assumes 'aws' command is configured with appropriate credentials and profile names
  # uploads.popuparchive.com is configured correctly.
  def copy_bucket_dir(token, old_bucket, verbose=false)
    new_bucket = ENV['AWS_BUCKET']
    # get contents of old bucket dir
    cmd = "aws s3 ls --profile prx s3://#{old_bucket}/#{token}/"
    verbose and puts cmd
    contents = %x( #{cmd} ).split(/$/).map(&:strip)
    dir_contents = {}
    contents.each do |line|
      ls_line = line.split
      next unless ls_line[3]
      # filename => size
      dir_contents[ ls_line[3] ] = ls_line[2]
    end
    verbose and pp dir_contents

    # copy them locally
    tmpdir   = "/tmp/s3-migrate/#{token}/"
    system("mkdir -p #{tmpdir}") or raise "Failed to create tmpdir #{tmpdir}: #{$?}"
    cp_cmd = "aws s3 --profile prx cp --recursive s3://#{old_bucket}/#{token}/ #{tmpdir}"
    verbose and puts cp_cmd
    system(cp_cmd) or raise "#{cp_cmd} failed: #{$?}"

    # create new bucket dir and sync
    sync_cmd = "aws s3 --profile pua sync #{tmpdir} s3://#{new_bucket}/#{token}/"
    verbose and puts sync_cmd
    system(sync_cmd) or raise "#{sync_cmd} failed: #{$?}"

    # verify everything copied ok
    ls_cmd = "aws s3 ls --profile pua s3://#{new_bucket}/#{token}/"
    verbose and puts ls_cmd
    new_contents = %x( #{ls_cmd} ).split(/$/).map(&:strip)
    new_dir_contents = {}
    new_contents.each do |line|
      ls_line = line.split
      next unless ls_line[3]
      new_dir_contents[ ls_line[3] ] = ls_line[2]
    end
    verbose and pp new_dir_contents

    # return value is whether contents are equal
    copy_ok = dir_contents == new_dir_contents
    
    # clean up
    if copy_ok
      system("rm -rf #{tmpdir}") or raise "Failed to clean up tmpdir #{tmpdir}: #{$?}"
    end

    copy_ok
  end

end
