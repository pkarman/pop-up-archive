require 'utils'
require 'voicebase'

class Tasks::VoicebaseTranscribeTask < Task

  before_validation :set_voicebase_defaults, :on => :create

  after_commit :create_transcribe_job, :on => :create

  def create_transcribe_job
    ProcessTaskWorker.perform_async(self.id) unless Rails.env.test?
  end

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
    conf = { configuration: { transcripts: { engine: "premium" } } }.to_json
    begin
      # TODO callback_url
      resp = client.upload( 
        media: data_file.path, 
        configuration: conf, 
        content_type: 'audio/mpeg; charset=binary'
      )
      if !resp or !resp.mediaId
        raise "No mediaId in Voicebase response for task #{self.id}"
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

  def self.voicebase_client
    client = VoiceBase::Client.new(
      :id     => ENV['VOICEBASE_AUTH_ID'],
      :secret => ENV['VOICEBASE_AUTH_SECRET'],
      :debug  => ENV['VOICEBASE_DEBUG'],
    )
    client
  end

  def lookup_job_by_name
    client = self.class.voicebase_client
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

  def update_premium_transcript_usage(now=DateTime.now)
    billed_user = user
    if !billed_user
      raise "Failed to find billable user with id #{user_id} (#{self.extras.inspect})"
    end

    # call on user.entity so billing goes to org if necessary
    ucalc = UsageCalculator.new(billed_user.entity, now)

    # call on user.entity so billing goes to org if necessary
    billed_duration = ucalc.calculate(Transcriber.voicebase, MonthlyUsage::PREMIUM_TRANSCRIPTS)

    # call again on the user if user != entity, just to record usage.
    if billed_user.entity != billed_user
      user_ucalc = UsageCalculator.new(billed_user, now)
      user_ucalc.calculate(Transcriber.voicebase, MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE)
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

  def recover!

    # easy cases first.
    if !owner
      self.extras['error'] = "No owner/audio_file found"
      cancel!
      return

    # if we have no vb_name, then we never downloaded in prep for job
    elsif !self.extras['vb_name']
      self.process()
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

    # cancel any rejected or failed jobs.
    if self.extras['vb_job_status'] == 'rejected' || self.extras['vb_job_status'] == "failed"
      self.extras['error'] = "Voicebase job #{self.extras['vb_job_status']}"
      cancel!
      return
    end

    # jobs marked 'expired' may still have a transcript. Only the audio is expired from their cache.
    if self.extras['vb_job_status'] == 'expired' or self.extras['vb_job_status'] == 'finished'
      finish!
      return
    end

    # if we get here, unknown status, so log and try to finish anyway.
    logger.warn("Task #{self.id} for Voicebase job #{self.extras['job_id']} has status '#{self.extras['vb_job_status']}'")
    finish!  # attempt to finish. Who knows, we might get lucky.

  end

  def finish_task
    return unless audio_file

    # verify job status is complete
    client = self.class.voicebase_client
    vb_job = client.get '/media/' + extras['job_id'] 
    return unless vb_job.media.status == 'finished' # not finished yet # TODO

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
    end
  end

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

      # TODO must be rewritten for voicebase structure
      # TODO requires that voicebase turn on speaker id
      speakers = response.speakers
      words    = response.words

      speaker_lookup = create_speakers(trans, speakers)

      # iterate through the words and speakers
      tt = nil
      speaker_idx = 0
      prev_speaker = 1
      words.each do |row|
        speaker = speakers[speaker_idx]
        row_end = BigDecimal.new(row['time'].to_s) + BigDecimal.new(row['duration'].to_s)
        speaker_end = speaker ? (BigDecimal.new(speaker['time'].to_s) + BigDecimal.new(speaker['duration'].to_s)) : row_end
        if tt
          if (row_end > speaker_end)
            tt.save
            speaker_idx += 1
            speaker = speakers[speaker_idx] ? speakers[speaker_idx] : speakers[prev_speaker] 
            tt = nil
          elsif (row_end - tt[:start_time]) > 5.0
            tt.save
            tt = nil
          else
            tt[:end_time] = row_end
            space = (row['name'] =~ /^[[:punct:]]/) ? '' : ' '
            tt[:text] += "#{space}#{row['name']}"
          end
        end

        if !tt
          tt = trans.timed_texts.build({
            start_time: BigDecimal.new(row['time'].to_s),
            end_time:   row_end,
            text:       row['name'],
            speaker_id: speaker ? speaker_lookup[speaker['name']].id : prev_speaker,
          })
          prev_speaker = tt.speaker_id
        end
        
      end

      trans.save!
    end
    trans
  end

  def create_speakers(trans, speakers)
    speakers_lookup = {}
    speakers_by_name = speakers.inject({}) {|all, s| all.key?(s['name']) ? all[s['name']] << s : all[s['name']] = [s]; all }
    speakers_by_name.keys.each do |n|
      times = speakers_by_name[n].collect{|r| [BigDecimal.new(r['time'].to_s), (BigDecimal.new(r['time'].to_s) + BigDecimal.new(r['duration'].to_s))] }
      speakers_lookup[n] = trans.speakers.create(name: n, times: times)
    end
    speakers_lookup
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

  def download_audio_file
    connection = Fog::Storage.new(storage.credentials)
    uri        = URI.parse(audio_file_url)
    Utils.download_file(connection, uri)
  end

  def audio_file_url
    audio_file.public_url(extension: :mp3)
  end

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

end
