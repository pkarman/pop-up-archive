class Tasks::TranscribeTask < Task

  before_validation :set_transcribe_defaults, :on => :create
  after_commit :create_transcribe_job, :on => :create

  def finish_task
    return unless audio_file
    return if cancelled?
    begin
      dest = destination
    rescue URI::InvalidComponentError => err
      self.extras['error'] = "Bad URI #{err}"
      self.cancel!
      return true
    end
    if dest and dest.length > 0
      self.extras['transcript'] = dest
      connection = Fog::Storage.new(storage.credentials)
      uri        = URI.parse(dest)
      begin
        transcript = get_file(connection, uri)
        new_trans  = process_transcript(transcript)

        # if new transcript resulted, then call analyze
        if new_trans
          audio_file.analyze_transcript
          notify_user unless start_only?
        end

      rescue Exceptions::PrivateFileNotFound => err
        # can't find the file.
        # if the task is older than a day, consider the file gone for good.
        if self.created_at < DateTime.now-1
          self.extras['error'] = "Failed to fetch transcript #{dest}: #{err}"
          self.cancel!
          return true
        end

        # otherwise, re-throw and we'll try again later
        raise err

      rescue Excon::Errors::Found => err
        # for whatever reason we got a fatal response (e.g. too many redirects)
        self.extras['error'] = "Failed to fetch transcript #{dest}: #{err}"
        self.cancel!
        return true

      rescue Excon::Errors::InternalServerError => err
        # unknown internal error
        self.extras['error'] = "Failed to fetch transcript #{dest}: #{err}"
        self.cancel!
        return true

      rescue
        raise # re-throw whatever it was

      end 
    else
      raise "No destination so cannot finish task #{id}"
    end
  end

  # :nocov:
  def recover!
    if !owner
      self.extras['error'] = "No owner/audio_file found"
      cancel!
    elsif !storage
      self.extras['error'] = 'No Storage defined'
      cancel!
    else
      begin
        finish!
      rescue Exceptions::PrivateFileNotFound => err
        # just log these, since we'll try again later
        puts err
      rescue
        raise  # re-throw
      end
    end 
  end
  # :nocov:

  def notify_user
    return unless (user && audio_file && audio_file.item)
    return if extras['notify_sent']
    if audio_file.item.extra.has_key? 'callback'
      CallbackWorker.perform_async(audio_file.item_id, audio_file.id, audio_file.item.extra['callback']) unless Rails.env.test?
    end
    r = TranscriptCompleteMailer.new_auto_transcript(user, audio_file, audio_file.item).deliver_now
    extras['notify_sent'] = DateTime.now.to_s
    r
  end

  def audio_file
    owner
  end

  def user
    User.find(user_id) if (user_id.to_i > 0)
  end

  def user_id
    self.extras['user_id']
  end

  # :nocov:
  def create_transcribe_job
    if start_only?
      j = create_job do |job|
        job.job_type    = 'audio'
        job.original    = original
        job.priority    = 2
        job.retry_delay = Task::RETRY_DELAY
        job.retry_max   = Task::MAX_WORKTIME / Task::RETRY_DELAY
        job.tasks       = [
          sequence: {
            tasks: [
              {
                task_type: 'cut', 
                options: {
                  length: 120, 
                  fade: 0
                }
              },
              {
                task_type: 'transcribe',
                result:    destination,
                call_back: call_back_url,
                label:     self.id,
                options:   transcribe_options
              }
            ]
          }
        ] 
        job
      end
    else
      j = create_job do |job|
        job.job_type = 'audio'
        job.original = original
        job.priority = 3
        job.retry_delay = Task::RETRY_DELAY
        job.retry_max   = Task::MAX_WORKTIME / Task::RETRY_DELAY
        job.tasks       = []
        job.tasks << {
          task_type: 'transcribe',
          result:    destination,
          call_back: call_back_url,
          label:     self.id,
          options:   transcribe_options
        }
        job
      end
    end

  end
  # :nocov:

  def update_transcript_usage(now=DateTime.now)
    billed_user = user
    if !billed_user
      raise "Failed to find billable user with id #{user_id} (#{self.extras.inspect})"
    end

    # we call user.entity because that will return the billable object
    ucalc = UsageCalculator.new(billed_user.entity, now)
    billed_duration = ucalc.calculate(MonthlyUsage::BASIC_TRANSCRIPTS)

    # call again on the user if user != entity, just to record usage.
    if billed_user.entity != billed_user
      user_ucalc = UsageCalculator.new(billed_user, now)
      user_ucalc.calculate(Transcriber.basic, MonthlyUsage::BASIC_TRANSCRIPT_USAGE)
    end

    return billed_duration
  end

  def process_transcript(json)
    return nil if json.blank?

    identifier = Digest::MD5.hexdigest(json)

    if trans = audio_file.transcripts.where(identifier: identifier).first
      logger.debug "transcript #{trans.id} already exists for this json: #{json[0,50]}"
      return false
    end

    trans_json = JSON.parse(json) if json.is_a?(String)
    transcriber = Transcriber.basic
    trans = audio_file.transcripts.build(
      language: 'en-US', 
      identifier: identifier, 
      start_time: 0, 
      end_time: 0, 
      transcriber_id: transcriber.id, 
      cost_per_min: transcriber.cost_per_min,
      retail_cost_per_min: transcriber.retail_cost_per_min,
      cost_type: Transcript::WHOLESALE,
      is_billable: self.force_basic? ? false : true,
      subscription_plan_id: audio_file.user.billable_subscription_plan_id,
    )
    sum = 0.0
    count = 0.0
    trans_json.each do |row|
      tt = trans.timed_texts.build({
        start_time: row['start_time'],
        end_time:   row['end_time'],
        confidence: row['confidence'],
        text:       row['text']
      })
      trans.end_time = tt.end_time if tt.end_time > trans.end_time
      trans.start_time = tt.start_time if tt.start_time < trans.start_time
      sum = sum + tt.confidence.to_f
      count = count + 1.0
    end
    trans.confidence = sum / count if count > 0

    save_transcript(trans)
  end

  def save_transcript(trans)
    # don't save this one if it is less time
    if audio_file.transcripts.where("transcripts.language = ? AND transcripts.end_time > ?", trans.language, trans.end_time).exists?
      logger.error "Not saving transcript for audio_file: #{audio_file.id} b/c end time is earlier: #{trans.end_time}"
      return nil
    end
    
    trans.save!
    # delete trans which cover less time
    partials_to_delete = audio_file.transcripts.where("language = ? AND end_time < ?", trans.language, trans.end_time)
    partials_to_delete.each{|t| t.destroy}
    trans
  end

  def transcribe_options
    {
      language:         'en-US',
      chunk_duration:   5,
      overlap:          0.5,
      max_results:      1,
      profanity_filter: true
    }
  end

  def start_only?
    !!extras['start_only']
  end

  def force_basic?
    extras['force_basic']
  end

  def destination
    suffix = start_only? ? '_ts_start.json' : '_ts_all.json'
    extras['destination'] || owner.try(:destination, {
      storage: storage,
      suffix:  suffix,
      options: { metadata: { 'x-archive-meta-mediatype' => 'data' } }
    })
  end

  def set_transcribe_defaults
    extras['entity_id']     = user.entity.id if user
    extras['duration']      = audio_file.duration.to_i if audio_file
  end

  def duration
    self.extras['duration'].to_i
  end

  def usage_duration
    if start_only?
      return 0  # first 2 minutes are always free
    end

    if duration and duration > 0
      duration
    elsif audio_file and !audio_file.duration.nil?
      self.extras['duration'] = audio_file.duration.to_s
      audio_file.duration
    else
      duration
    end

  end

end
