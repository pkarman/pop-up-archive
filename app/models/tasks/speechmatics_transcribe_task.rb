require 'utils'
require 'speechmatics'

class Tasks::SpeechmaticsTranscribeTask < Task

  before_validation :set_speechmatics_defaults, :on => :create

  after_commit :create_transcribe_job, :on => :create

  def create_transcribe_job
    # download audio file
    data_file = download_audio_file
    sm = Speechmatics::Client.new
    info = sm.user.jobs.create(
      data_file:    data_file.path,
      content_type: 'audio/mpeg; charset=binary',
      notification: 'callback',
      callback:     call_back_url
    )

    self.extras['job_id'] = info.id
    self.save!
  end

  def finish_task
    return unless audio_file

    sm = Speechmatics::Client.new
    transcript = sm.user.jobs(self.extras['job_id']).transcript
    new_trans  = process_transcript(transcript)

    # if new transcript resulted, then call analyze
    if new_trans
      audio_file.analyze_transcript
      notify_user unless start_only?
    end
  end

  def process_transcript(response)
    return nil if response.blank? || response.body.blank?

    json = response.body.to_json
    identifier = Digest::MD5.hexdigest(json)

    if trans = audio_file.transcripts.where(identifier: identifier).first
      logger.debug "transcript #{trans.id} already exists for this json: #{json[0,50]}"
      return false
    end

    trans = audio_file.transcripts.build(language: 'en-US', identifier: identifier, start_time: 0, end_time: 0)

    speakers = response.speakers
    words = response.words

    # iterate through the words and speakers
    tt = nil
    speaker_idx = 0
    words.each do |row|
      speaker = speakers[speaker_idx]

      row_end = BigDecimal.new(row['time'].to_s) + BigDecimal.new(row['duration'].to_s)
      speaker_end = BigDecimal.new(speaker['time'].to_s) + BigDecimal.new(speaker['duration'].to_s)

      if tt
        if (row_end > speaker_end)
          speaker_idx += 1
          tt.save
          tt = nil
        elsif (row_end - tt[:start_time]) > 5.0
          tt.save
          tt = nil
        else
          tt[:end_time] = row_end
          space = (row['name'] =~ /[[:punct:]]/) ? '' : ' '
          tt[:text] += "#{space}#{row['name']}"
        end
      end

      if !tt
        tt = trans.timed_texts.build({
          start_time: BigDecimal.new(row['time'].to_s),
          end_time:   row_end,
          text:       row['name'],
          speaker:    speaker['name']
        })
      end
    end

    trans.save!
    trans
  end

  def set_speechmatics_defaults
    extras['call_back_url'] = speechmatics_call_back_url
  end

  def speechmatics_call_back_url
    Rails.application.routes.url_helpers.speechmatics_callback_url(model_name: owner.class.model_name.underscore, id: owner.id)
  end

  def download_audio_file
    connection = Fog::Storage.new(storage.credentials)
    uri        = URI.parse(audio_file_url)
    Utils.download_temp_file(connection, uri)    
  end

  def audio_file_url
    extras['destination'] || owner.try(:destination, {
      storage: storage,
      version: 'mp3'
    })
  end

  def notify_user
    return unless (user && audio_file && audio_file.item)
    TranscriptCompleteMailer.new_auto_transcript(user, audio_file, audio_file.item).deliver
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

end
