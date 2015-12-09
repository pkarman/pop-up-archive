class FeedPopUp

  require 'uri'
  require 'pathname'
  # adding this for testing feed parsing in an easier way
  attr_accessor :dry_run
  
  def self.update_from_feed(feed_url, collection_id, dry_run=false, oldest_entry=nil)
    feed_pop_up = FeedPopUp.new(dry_run, oldest_entry)
    feed_pop_up.parse(feed_url, collection_id)
  end
 
  def initialize(dry_run=false, oldest_entry='1900-01-01')
    self.dry_run = dry_run
    @oldest_entry = DateTime.parse(oldest_entry||'1900-01-01')
  end
 
  def parse(feed_url, collection_id)
    able_to_parse = true
    collection = Collection.find(collection_id) # this will throw an error if not present
    parsed = 0
    begin
      feed = Feedjira::Feed.fetch_and_parse(feed_url, :on_failure => proc { |c,err| STDERR.puts "#{c} #{err}"})
      if feed && feed.entries && feed.entries.size > 0
        parsed = add_entries(feed.entries, collection)
      end
    rescue => err
      # re-throw
      raise err
    end
    parsed
  end
 
  def add_entries(entries, collection)
    # cache all items idk values in memory for easy lookup to help prevent dupes
    item_cache = {}
    collection.items.each do |item|
      idk = "#{item.title}:#{item.date_created}"
      item_cache[idk] = item.id
    end
    newItems = 0
    entries.each do |entry|
      next if entry.published < @oldest_entry
      next if !entry['enclosure_url'] 
      # always brute force avoid same title, same publish date, same URL, to keep dupes out.
      # TODO this is less than ideal but the id() method isn't strict enough.
      idk = "#{entry.title}:#{entry.published}".gsub(/\ \d\d:\d\d:\d\d UTC$/, '')
      next if item_cache.has_key? idk
      unless Item.where(identifier: id(entry), collection_id: collection.id).exists?
        item = add_item_from_entry(entry, collection)
        newItems += 1
        item_cache[idk] = item.id
      end
    end
    newItems
  end
 
  def add_item_from_entry(entry, collection)
    item = Item.new
 
    item.collection       = collection
    item.description      = sanitize_text(entry.summary)
    item.title            = entry.title || entry.enclosure_url 
    item.identifier       = id(entry)
    item.digital_location = entry.url
    item.date_broadcast   = entry.published
    item.date_created     = entry.published
    item.tags = entry.respond_to?(:categories) ? entry.categories : []
    
    author = author(entry)
    item.creators         = [author] if author
    add_audio_files(item, entry, collection)
    add_image_files(item, entry, collection)
  
    item.save! unless dry_run
    if ENV['VERBOSE']
      puts entry.inspect
      puts item.inspect
    end
    item
  end
 
  def author(entry)
    n = entry.try(:author) ? entry.author.sanitize.squish : nil
    p = Person.for_name(n) if n
    p
  end

  def etag(entry)
    url = entry.try(:enclosure_url) || entry.try(:guid) || entry.try(:url)
    url = CGI.unescapeHTML(url)
    #puts "etag(#{url})"
    head_resp = Utils.head_resp(url)
    etag = head_resp.headers['ETag']
    #puts head_resp.headers.inspect
    if etag
      etag.gsub!(/\A"|"\Z/, '')  # strip enclosing quotes
      # if this is NPR-style : delimited, we just want the md5 checksum (32 chars), not the timestamp
      if m = etag.match(/^(\w{32}):(\d+)$/)
        return m[1]
      else
        return nil  # be conservative. only accept known Etag formats.
      end
    end
    nil
  end
       
  def id(entry)
    etag(entry) ||
    entry.try(:enclosure_url) ||
    entry.try(:entry_id) ||
    entry.try(:guid) ||
    entry.try(:url) ||
    generate_id(entry)
  end
 
  def generate_id(entry)
    uniq = "#{entry.title.sanitize}|#{entry.published}"
    Digest::MD5.hexdigest(uniq)
  end
 
  def add_audio_files(item, entry, collection)
    if entry['enclosure_url']
      add_audio_file(item, entry.enclosure_url, collection)
    end
  end
 
  def add_audio_file(item, url, collection)
    url = CGI.unescapeHTML(url)
    return unless Utils.is_audio_file?(url)
    audio = AudioFile.new
    audio.user            = collection.creator
    audio.identifier      = url
    audio.remote_file_url = url
    item.audio_files << audio
    audio
  end
  
  def add_image_files(item, entry, collection)
    if entry['image'] 
      add_image_file(item, entry.image, collection) 
    end
  end
 
  def add_image_file(item, url, collection)
    url = CGI.unescapeHTML(url)
    uri = URI.parse(URI.encode(url.strip))     
    return unless Utils.is_image_file?(url)
    image_file = ImageFile.new
    puts image_file.inspect.to_s
    file_name = Pathname.new(uri.path).basename.to_s
    image_file.file = file_name
    image_file.remote_file_url = url
    item.image_files << image_file
    image_file
  end
 
  def sanitize_text(text)
    transformer = lambda do |env|
      node      = env[:node]
      node_name = env[:node_name]
 
      # Don't continue if this node is already whitelisted or is not an element.
      return if env[:is_whitelisted] || !node.element?
 
      # Don't continue unless the node is an div.
      return unless node_name == 'div'
 
      # We're now certain that this is a div in the summary,
      Sanitize.clean_node!(node)
 
      # Now that we're sure that this is a valid YouTube embed and that there are
      # no unwanted elements or attributes hidden inside it, we can tell Sanitize
      # to whitelist the current node.
      {:node_whitelist => [node]}
    end
 
    Sanitize.clean(text,
      :transformers => transformer,
      :elements     => ['a', 'span'],
      :attributes   => {'a' => ['href', 'title'], 'span' => ['class']},
      :protocols    => {'a' => {'href' => ['http', 'https', 'mailto']}}
    )
  end
 
  def logger
    Rails.logger
  end
 
end
