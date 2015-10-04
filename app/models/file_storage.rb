require 'active_support/concern'

module FileStorage
  extend ActiveSupport::Concern

  included do
    has_many :tasks, as: :owner
    belongs_to :storage_configuration, class_name: "StorageConfiguration", foreign_key: :storage_id

    attr_accessor :should_trigger_fixer_copy
  end

  def has_file?
    !self.file.try(:path).nil?
  end

  def copy_media?
    item.collection.copy_media
  end

  def storage
    storage_configuration || self.get_storage
  end

  def get_storage
    raise "#{self.class} does not implement get_storage method"
  end

  def get_token
    item.try(:token)
  end

  def store_dir(stor=storage)
    p = self.respond_to?(:path) ? self.path : ''
    return nil unless stor.use_folders?
    tok = self.get_token
    return "#{tok}/#{p}" 
  end

  def upload_to
    # needs change for collection image?
    storage.direct_upload? ? storage : item.upload_to
  end

  def url(*args)
    has_file? ? file.try(:url, *args) : original_file_url
  end

  def update_file!(name, sid)
    sid = sid.to_i
    file_will_change!
    raw_write_attribute(:file, name)
    if (sid > 0) && (self.storage.id != sid)
      # see if the item is right
      if item.storage.id == sid
        self.storage_id = nil
        self.storage_configuration = nil
      else
        self.storage.id = sid
        self.storage_configuration = StorageConfiguration.find(sid)
      end
    end
    
    save!
  end  

  def copy_original
    return false unless (should_trigger_fixer_copy && copy_media? && original_file_url)
    create_copy_task(original_file_url, destination, storage)
    self.should_trigger_fixer_copy = false
  end

  def item_storage
    item.storage
  end

  def copy_to_item_storage
    # refresh storage related
    file_storage = self.storage_configuration
    item_storage = self.item_storage
    # file_storage = self.storage_configuration
    # item_storage = item.storage
    # puts "\ncopy_to_item_storage: storage(#{file_storage.inspect}) == item.storage(#{item_storage.inspect})\n"
    return false if (!file_storage || (file_storage == item_storage))

    orig = destination
    dest = destination(storage: item_storage)
    # puts "\ncopy_to_item_storage: create task: orig: #{orig}, dest: #{dest}, stor: #{item_storage.inspect}\n"
    create_copy_task(orig, dest, item_storage)
    return true
  end
  
  def remote_file_url=(url)
    self.original_file_url = url
    self.should_trigger_fixer_copy = !!url
  end
  
  def resource_user
    self.user if self.respond_to?(:user)
  end

  def create_copy_task(orig, dest, stor)
    # see if there is already a copy task
    if task = (tasks.copy.valid.where(identifier: dest).last || tasks.select { |t| t.type = "Tasks::CopyTask" && !t.cancelled? && t.identifier == dest }.pop)
      logger.debug "copy task #{task.id} already exists for file #{self.class.name}:#{self.id}"
    else

      # protocol-free links are valid for browsers but not for us
      if orig.match('^//')
        orig = 'http:' + orig
      end 

      task = Tasks::CopyTask.new(
        identifier: dest,
        storage_id: stor.id,
        extras: {
          'user_id'     => resource_user.try(:id),
          'original'    => orig,
          'destination' => dest
        }

      )
      self.tasks << task
    end
    task
  end

  def call_back_url
    Rails.application.routes.url_helpers.fixer_callback_url(model_name: self.class.model_name.underscore, id: id)
  end

  def use_original_file_url?
    !copy_media? || !has_file?
  end

  def process_file_url(version='mp3')
    #account for the fact that the IA is case sensitive when matching file extension
    # if storage.provider == "InternetArchive" and /\.MP3/.match(file.path)
    #   return "https://archive.org/download/#{file.model.destination_directory}/#{file.path}"
    # end
    return file.url(version)   if storage.is_public? && file.url(version)
    return original_file_url if use_original_file_url? && original_file_url
    destination
  end

  def process_version_url(options)
    return file.url(options) if storage.is_public?
    destination
  end

  def destination_options(options={})
    stor = options[:storage] || storage
    dest_opts = options[:options] || {}
    da = stor.provider_attributes || {}
    da.reverse_merge!(dest_opts)

    if stor.at_internet_archive?
      if Rails.env.production?
        da[:collections] = [] unless da.has_key?(:collections)
        da[:collections] << 'popuparchive' unless da[:collections].include?('popuparchive')
      end

      default_subject = self.collection_title
      da[:subjects] = [] unless da.has_key?(:subjects)
      da[:subjects] << default_subject unless da[:subjects].include?(default_subject)

      da[:metadata] = {} unless da.has_key?(:metadata)
      da[:metadata]['x-archive-meta-title'] ||= item.try(:title)
      da[:metadata]['x-archive-meta-mediatype'] ||= self.mime_type
    end

    da
  end

  def mime_type
    self.class.name.underscore.gsub(/_file$/,'')
  end

  def destination_path(options={})
    dir = store_dir(options[:storage] || storage) || ''
    version = options.delete(:version)
    # version = options[:version] || ''
    File.join("/", dir, filename(version))
  end

  def filename(version=nil)
    fn = if has_file?
      f = version ? file.send(version) : file
      File.basename(f.path)
    elsif !original_file_url.blank?
      f = URI.parse(original_file_url).path || ''
      x = File.extname(f)
      v = !version.blank? ? ".#{version}" : nil
      File.basename(f, x) + (v || x)
    end || ''
    fn
  end  

  def destination_directory(options={})
    stor = options[:storage] || storage
    stor.use_folders? ? stor.bucket : self.get_token
  end

  def destination(options={})
    stor   = options[:storage] || storage
    suffix = options[:suffix]  || ''

    scheme = case stor.provider.downcase
    when 'aws' then 's3'
    when 'internetarchive' then 'ia'
    else 's3'
    end

    opts = destination_options(options)
    query = opts.inject({}){|h, p| h["x-fixer-#{p[0]}"] = p[1]; h}.to_query if !opts.blank?

    host = destination_directory(options)
    path = destination_path(options) + suffix

    uri = URI::Generic.build scheme: scheme, host: host, path: path, query: query
    if scheme == 'ia'
      uri.user = stor.key
      uri.password = stor.secret
    end
    uri.to_s
  end

  def update_from_fixer(params)
    # get the task id from the label
    task = tasks.where(id: params['label']).last
    return unless task

    task.update_from_fixer(params)

  rescue Exception => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
  end  

end
