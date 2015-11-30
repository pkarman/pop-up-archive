require 'utils'
require 'voicebase'

class Tasks::VoicebaseTranscribeTask < Task

  before_validation :set_voicebase_defaults, :on => :create

  after_commit :create_transcribe_job, :on => :create

  def create_transcribe_job
    ProcessTaskWorker.perform_async(self.id) unless Rails.env.test?
  end

  # :nocov:
  def process

    # sanity check -- have we already created a remote request?
    if self.extras['job_id']
      self.extras['log'] = 'process() called on existing job_id'
      return self
    end

    # do we actually have an owner?
    if !owner
      self.extras['error'] = 'No owner/audio_file found'
      self.save!
      return
     end

    # download audio file
    data_file = download_audio_file

    # remember the temp file name so we can look up later
    self.extras['vb_name'] = File.basename(data_file.path)
    self.save!

    # create the remote job
    client = self.class.voicebase_client
    conf = { 
      configuration: { 
        transcripts: { engine: "premium" },
        publish: { 
          callbacks: [{  
            method: "POST", 
            include: ["transcripts", "topics", "metadata"], 
            url: voicebase_call_back_url(),
          }]  
        }   
      }   
    }.to_json
    begin
      resp = client.upload( 
        media: data_file.path, 
        configuration: conf, 
      )
      if !resp or !resp.respond_to?(:mediaId)
        raise "No mediaId in Voicebase response for task #{self.id}: #{resp.inspect}"
      end

      # save the job reference
      self.extras['job_id'] = resp.mediaId
      # if we previously had an error, zap it
      if self.extras['error'] == "No Voicebase mediaId found"
        self.extras.delete(:error)
      end
      self.status = :working
      self.save!

    rescue Faraday::Error::TimeoutError => err

      # it is possible that VB got the request
      # but we failed to get the response.
      # so check back to see if a record exists for our file.
      job_id = self.lookup_job_by_name
      if !job_id
        raise "No job_id captured for job in task #{self.id}"
      end

    rescue
      # re-throw original exception
      raise
    end

  end
  # :nocov:

  # :nocov:
  def self.voicebase_client
    client = VoiceBase::Client.new(
      :id     => ENV['VOICEBASE_AUTH_ID'],
      :secret => ENV['VOICEBASE_AUTH_SECRET'],
      :debug  => ENV['VOICEBASE_DEBUG'],
    )
    client
  end
  # :nocov:

  # :nocov:
  def lookup_job_by_name
    # we might have the id via the callback
    if extras['vb_job_id_via_callback']
      self.extras['job_id'] = extras['vb_job_id_via_callback']
      self.save!
      return self
    end

    # otherwise go look for it
    client = self.class.voicebase_client
    # ########################## TODO ###########################
    # TODO iterate through /media
    jobs = client.get '/media'
    job_id  = nil
    jobs.each do|j|
      if false  # TODO logic here
        # yes, it was successful
        self.extras['job_id'] = job_id = j['mediaId']
        self.save!
        break
      end 
    end
    job_id
  end
  # :nocov:

  def update_premium_transcript_usage(now=DateTime.now)
    billed_user = user
    if !billed_user
      raise "Failed to find billable user with id #{user_id} (#{self.extras.inspect})"
    end

    # call on user.entity so billing goes to org if necessary
    ucalc = UsageCalculator.new(billed_user.entity, now)

    # call on user.entity so billing goes to org if necessary
    billed_duration = ucalc.calculate(MonthlyUsage::PREMIUM_TRANSCRIPTS)

    # call again on the user if user != entity, just to record usage.
    if billed_user.entity != billed_user
      user_ucalc = UsageCalculator.new(billed_user, now)
      user_ucalc.calculate(MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE)
    end

    return billed_duration
  end

  def stuck?
    # cancelled jobs are final.
    return false if status == CANCELLED
    return false if status == COMPLETE

    # older than max worktime and incomplete
    if outside_work_window?
      return true

    # we failed to register a job_id
    elsif !extras['job_id']
      return true

    # process() seems to have failed
    elsif !extras['vb_name']
      return true

    end

    # if we get here, not stuck
    return false
  end

  # :nocov:
  def recover!

    # easy cases first.
    if !owner
      self.extras['error'] = "No owner/audio_file found"
      cancel!
      return

    # if we have no vb_name, then we never downloaded in prep for job
    elsif !self.extras['vb_name']
      begin
        self.process()
      rescue => err
        logger.warn(err)
        self.extras['error'] = err
        cancel!
      end
      return

    elsif !self.extras['job_id']
      # try to look it up, one last time
      if !self.lookup_job_by_name
        self.extras['error'] = "No Voicebase job_id found"
        cancel!
        return
      end
    end

    # call out to VB and find out what our status is
    client = self.class.voicebase_client
    vb_job = client.get '/media/' + extras['job_id']
    self.extras['vb_job_status'] = vb_job.media.status

    if self.extras['vb_job_status'] == 'running' || self.extras['vb_job_status'] == 'accepted'
      # if VB is still working, return without doing anything
      logger.warn("Task #{self.id} for Voicebase job #{self.extras['job_id']} still running")
      return
    end

    # cancel any rejected or failed jobs.
    if self.extras['vb_job_status'] == 'rejected' || self.extras['vb_job_status'] == "failed"
      self.extras['error'] = "Voicebase job #{self.extras['vb_job_status']}"
      cancel!
      return
    end

    if vb_job.media.transcripts && vb_job.media.transcripts.latest.words.count == 0
      self.extras['error'] = "Voicebase job empty"
      self.status = 'failed'
      self.save!
      return
    end

    # jobs marked 'expired' may still have a transcript. Only the audio is expired from their cache.
    if self.extras['vb_job_status'] == 'expired' or self.extras['vb_job_status'] == 'finished'
      finish!
      return
    end

    # if we get here, unknown status
    raise("Task #{self.id} for Voicebase job #{self.extras['job_id']} has unknown status '#{self.extras['vb_job_status']}'")

  end
  # :nocov:

  # :nocov:
  def finish_task
    return unless audio_file

    client = self.class.voicebase_client

    # verify job status is complete
    if extras['job_status'] != "finished"
      vb_job = client.get '/media/' + extras['job_id']
      if vb_job.media.status != "finished"
        raise "Cannot finish task where VB status != finished (#{vb_job.media.status})"
      else
        extras['job_status'] = vb_job.media.status
      end
    end

    transcript = nil
    begin
      transcript = client.transcripts extras['job_id']
    rescue => err
      # if VB throws an error (e.g. 404) we just warn and return
      # since we can't proceed.
      # TODO is this too soft? should we examine and/or re-throw?
      #logger.warn(err)
      raise err
      return
    end
    if !transcript
      raise "No Voicebase transcript found"
    end

    new_trans  = process_transcript(transcript)

    # if new transcript resulted, then call analyze
    if new_trans
      audio_file.analyze_transcript

      # show usage immediately
      update_premium_transcript_usage

      # create audit xref
      self.extras[:transcript_id] = new_trans.id

      # if we previously had an error, zap it
      if self.extras['error']
        self.extras.delete(:error)
      end

      self.save!

      # share the glad tidings
      notify_user

      # update status
      audio_file.set_current_status
      audio_file.save!

    else
      raise "Failed to process transcript from response: #{response.inspect}"
    end
  end
  # :nocov:

  def process_transcript(response)
    trans = nil
    return trans if response.blank? || response.body.blank?

    json = response.body.to_json
    identifier = Digest::MD5.hexdigest(json)

    if trans = audio_file.transcripts.where(identifier: identifier).first
      logger.debug "transcript #{trans.id} already exists for this json: #{json[0,50]}"
      return trans
    end

    transcriber = Transcriber.voicebase

    # if this was an ondemand transcript, the cost is retail, not wholesale.
    # 'wholesale' is the cost PUA pays, and translates to zero to the customer under their plan.
    # 'retail' is the cost the customer pays, if the transcript is on-demand.
    cost_type = Transcript::WHOLESALE
    if self.extras['ondemand']
      cost_type = Transcript::RETAIL
    end

    Transcript.transaction do
      trans    = audio_file.transcripts.create!(
        language: 'en-US',  # TODO get this from audio_file?
        identifier: identifier,
        start_time: 0,
        end_time: 0,
        transcriber_id: transcriber.id,
        cost_per_min: transcriber.cost_per_min,
        retail_cost_per_min: transcriber.retail_cost_per_min,
        cost_type: cost_type,
        subscription_plan_id: audio_file.user.billable_subscription_plan_id,
      )

      # Voicebase does not currently support speakers w/o clumsy stereo channel assignments,
      # so we do not assign speakers.
      #STDERR.puts response.pretty_inspect
      words = response.body.transcript.words

      # iterate through the words 
      tt = nil # re-use for re-chunking
      tt_confidences = []
      words.each_with_index do |row, idx|
      # example format
      # {"p"=>1, "c"=>0.904, "s"=>9, "e"=>2403, "w"=>"we"}
      # where
      # p == position
      # s == start time in ms
      # e == end time in ms
      # c == confidence
      # w == word (term)
      # m == metadata (flag for punctuation, speaker, etc)

      # we re-chunk up the individual words into phrases of ~ 5sec
        row_end = BigDecimal.new(row['e'].fdiv(1000).to_s)
        next_row = words[idx+1] ? words[idx+1] : nil
        tt_confidences.push row['c']
        is_punc = false
        if tt
          tt[:end_time] = row_end
          if row['m']
            # always keep punctuation with the word it follows
            if row['m'] == "punc"
              tt[:text] += row['w']
              is_punc = true
            end
          else
            space = (row['w'] =~ /^[[:punct:]]/) ? '' : ' '
            tt[:text] += "#{space}#{row['w']}"
          end
          # end the chunk if we are over 5sec and the next word is not punctuation.
          if (row_end - tt[:start_time]) > 5.0 && (!next_row || !next_row['m'])
            tt[:confidence] = tt_confidences.inject{ |sum, el| sum + el }.to_f / tt_confidences.size
            tt.save
            tt = nil
            tt_confidences = [] 
          end
        else 
          tt = trans.timed_texts.build({
            start_time: BigDecimal.new(row['s'].fdiv(1000).to_s),
            end_time:   BigDecimal.new(row['e'].fdiv(1000).to_s),
            text:       row['w'],
            speaker_id: nil,  # some day...
          })
        end
      end

      trans.save!
    end
    trans
  end

  def set_voicebase_defaults
    extras['public_id']     = SecureRandom.hex(8)
    extras['call_back_url'] = voicebase_call_back_url
    extras['entity_id']     = user.entity.id if user
    extras['duration']      = audio_file.duration.to_i if audio_file
  end

  def voicebase_call_back_url
    Rails.application.routes.url_helpers.voicebase_callback_url(model_name: 'task', model_id: self.extras['public_id'])
  end

  # :nocov:
  def download_audio_file
    connection = Fog::Storage.new(storage.credentials)
    uri        = URI.parse(audio_file_url)
    Utils.download_file(connection, uri)
  end
  # :nocov:

  def audio_file_url
    audio_file.public_url(extension: :mp3)
  end

  # :nocov:
  def notify_user
    return unless (user && audio_file && audio_file.item)
    return if extras['notify_sent']
    if audio_file.item.extra.has_key? 'callback'
      CallbackWorker.perform_async(audio_file.item_id, audio_file.id, audio_file.item.extra['callback']) unless Rails.env.test?
    end
    r = TranscriptCompleteMailer.new_auto_transcript(user, audio_file, audio_file.item).deliver_now
    self.extras['notify_sent'] = DateTime.now.to_s
    self.save!
    r
  end
  # :nocov:

  def audio_file
    owner
  end

  def user
    User.find(user_id) if (user_id.to_i > 0)
  end

  def user_id
    self.extras['user_id']
  end

  def duration
    self.extras['duration'].to_i
  end

  # this method does not appear to be used anywhere
  # :nocov:
  def usage_duration
    # if parent audio_file gets its duration updated after the task was created, for any reason, prefer it
    if duration and duration > 0
      duration
    elsif !audio_file.duration.nil?
      self.extras['duration'] = audio_file.duration.to_s
      audio_file.duration
    else
      duration
    end
  end
  # :nocov:

end
