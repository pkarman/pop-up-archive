class Transcript < ActiveRecord::Base
  attr_accessible :language, :audio_file_id, :identifier, :start_time, :end_time, :confidence, :transcriber_id, :cost_per_min, :cost_type, :retail_cost_per_min, :is_billable, :subscription_plan_id

  belongs_to :audio_file
  belongs_to :transcriber
  belongs_to :subscription_plan
  has_one :item, through: :audio_file
  has_many :timed_texts, -> { order 'start_time ASC' }
  has_many :speakers

  default_scope -> { includes(:timed_texts) }

  after_save :update_item
  after_update :update_usage, if: :is_billable_changed?

  RETAIL    = 2 
  WHOLESALE = 1 
  COST_TYPES = {RETAIL => "Retail", WHOLESALE => "Wholesale"}

  def plan
    if subscription_plan
      subscription_plan.as_cached
    else
      audio_file_lazarus.user.plan
    end
  end

  def billed_as
    COST_TYPES[self.cost_type]
  end

  def update_item
    IndexerWorker.perform_async(:update, item.class.to_s, item.id) if item
  end

  def timed_texts
    super.each do |tt|
      tt.transcript = self
    end
    super
  end

  def set_confidence
    sum = 0.0
    count = 0.0
    self.timed_texts.each{|tt| sum = sum + tt.confidence.to_f; count = count + 1.0}
    if count > 0.0
      average = sum / count
      self.update_attribute(:confidence, average)
    end
    average
  end

  def as_json(options={})
    { sections: timed_texts }
  end

  # def to_doc(format=:srt)
  #   action_view = ActionView::Base.new(Rails.configuration.paths["app/views"])
  #   action_view.class_eval do 
  #     include Rails.application.routes.url_helpers
  #     include Api::BaseHelper
  #     def protect_against_forgery?; false; end
  #   end

  #   action_view.render(template: 'api/v1/transcripts/show', formats: [format], locals: {transcript: self})
  # end

  def to_srt
    srt = ""
    timed_texts.each_with_index do |tt, index|

      end_time = tt.end_time
      end_mils = '000'

      if (index + 1) < timed_texts.size
        end_time_max = [(timed_texts[index + 1].start_time - 1), 0].max
        end_time = [tt.end_time, end_time_max].min
        end_mils = '999'
      end

      if (index > 0)
        srt += "\r\n" 
      end

      srt += "#{index + 1}\n"
      srt += "#{format_time(tt.start_time)},000 --> #{format_time(end_time)},#{end_mils}\n"
      srt += tt.text + "\n"
    end
    srt
  end

  def speaker_name(speaker_id)
    # memoize lookup by id
    if !@_speakers_by_id
      @_speakers_by_id = {}
      speakers.each do |sp|
        @_speakers_by_id[sp.id] = sp
      end
    end
    @_speakers_by_id[speaker_id].name
  end

  def has_speaker_ids
    self.timed_texts.where("speaker_id is not null").count > 0 ? true : false
  end

  # return array of timed texts, grouped by speaker change
  # each item in the array is a HashWithIndifferentAccess object,
  # with keys: start, speaker, text, offsets
  def chunked_by_speaker
    chunks = []
    cur_chunk = nil
    prev_speaker = nil
    timed_texts.each do |tt|
      speaker_name = self.speaker_name(tt.speaker_id)
      if !cur_chunk or !prev_speaker or speaker_name != prev_speaker
        prev_speaker = speaker_name
        if cur_chunk
          chunks.push cur_chunk
        end
        cur_chunk = HashWithIndifferentAccess.new
        cur_chunk[:speaker] = speaker_name
        cur_chunk[:start]   = tt.start_time
        cur_chunk[:ts]      = tt.offset_as_ts
        cur_chunk[:text]    = [tt.text]
        cur_chunk[:offsets] = [tt.start_time]
        next
      end
      cur_chunk[:text].push tt.text
      cur_chunk[:offsets].push tt.start_time
      prev_speaker = speaker_name
    end
    if cur_chunk and cur_chunk[:text].size > 0
      chunks.push cur_chunk  # last one
    end
    chunks
  end

  # returns array of timed texts, grouped by 'chunk_size' seconds.
  # default is '30' seconds per chunk.
  # format of response is same as chunked_by_speaker() except for 'speaker'
  def chunked_by_time(chunk_size=30)
    chunks = []
    cur_chunk = nil
    prev_start = nil
    timed_texts.each do |tt|
      start_time = tt.start_time.to_i
      if !cur_chunk or !prev_start or (start_time - prev_start) > chunk_size
        #puts "prev_start=#{prev_start.inspect}  start_time=#{start_time.inspect}  chunk_size=#{chunk_size.inspect}"
        prev_start = start_time
        if cur_chunk
          chunks.push cur_chunk
        end 
        cur_chunk = HashWithIndifferentAccess.new
        cur_chunk[:start]   = start_time
        cur_chunk[:ts]      = tt.offset_as_ts
        cur_chunk[:text]    = [tt.text]
        cur_chunk[:offsets] = [tt.start_time]
        next
      end 
      cur_chunk[:text].push tt.text
      cur_chunk[:offsets].push tt.start_time
    end 
    if cur_chunk and cur_chunk[:text].size > 0 
      chunks.push cur_chunk  # last one
    end 
    chunks
  end

  # since billing ignores whether an audio_file was deleted, provide a getter
  # that ignores the paranoia deleted_at value.
  # NOTE that Rails 4.x w/ ActiveRecord 5.x may have the option of a :with_deleted
  # association definition, making this hand-constructed query unneccessary.
  def audio_file_lazarus
    AudioFile.with_deleted.find self.audio_file_id
  end

  def is_premium?
    if Transcriber.ids_for_type('premium').include?(self.transcriber_id)
      true
    else
      false
    end
  end

  def duration
    return 0 unless self.end_time && self.start_time
    self.end_time - self.start_time
  end

  def is_preview?
    af = self.audio_file_lazarus
    self.transcriber_id == Transcriber.basic.id && self.duration <= 120 && af.duration && af.duration > 120
  end

  def is_basic?
    self.transcriber_id == Transcriber.basic.id && !self.is_preview?
  end

  def flavor
    return 'Premium' if is_premium?
    return 'Basic'   if is_basic?
    return 'Preview' if is_preview?
    return 'Unknown'
  end

  def billable?
    self.is_billable
  end

  # returns a User or Organization
  def billable_to
    audio_file_lazarus.billable_to
  end

  # returns the billable seconds
  # optional single arg is the audio_file this transcript references,
  # to avoid the sql load overhead when calculating (see User.transcripts_billable_for_month_of)
  def billable_seconds(af=audio_file_lazarus)
    if end_time == 120 and start_time == 0 and cost_per_min == 0

      # 2min preview is free 
      # TODO better way to identify these. Perhaps a special Transcriber?
      return 0

    elsif af.duration

      # prefer audio file over actual transcript time
      # since we want people to pay for the privilege
      # of discovering parts of their audio are unintelligible.
      return af.duration

    else

      # default is the transcript length
      return end_time - start_time

    end
  end

  def billable_hms(af=audio_file_lazarus)
    format_time(billable_seconds(af))
  end

  # returns a float representing 1000ths of a dollar
  # is_billable flag is ignored, since this is the wholesale cost.
  def cost(af=audio_file_lazarus)
    #return 0.0 if !billable?
    secs = billable_seconds(af)
    mins = secs.fdiv(60)
    return cost_per_min.to_f * mins.to_f
  end

  # returns a float representing 1000ths of a dollar
  # if billable? is false, always returns 0.0
  def retail_cost(af=audio_file_lazarus)
    return 0.0 if !billable?
    return 0.0 if cost_type == WHOLESALE
    secs = billable_seconds(af)
    mins = secs.fdiv(60)
    return retail_cost_per_min.to_f * mins.to_f
  end

  # returns a float in dollars
  def cost_dollars(af=audio_file_lazarus)
    return cost(af) / 1000
  end

  def retail_cost_dollars(af=audio_file_lazarus)
    return retail_cost(af) / 1000
  end

  def as_usage_summary(af=audio_file_lazarus)
    { 
      :time => billable_hms(af),
      :cost => billable? ? retail_cost_dollars(af) : 0.0,
      :date => created_at,
      :name => af.filename,
      :title => af.item.title,
      :user => { :id => af.user.id, :name => af.user.name },
      :id   => id,
      :coll_id => af.item.collection_id,
      :item_id => af.item_id,
      :deleted => (af.deleted? || af.item.deleted?),
      :flavor  => flavor,
    }
  end

  private

  def format_time(seconds)
    Time.at(seconds).getgm.strftime('%H:%M:%S')
  end

  def update_usage
    user=audio_file.user
    user.calculate_monthly_usages!
    usage = user.usage_for(MonthlyUsage::PREMIUM_TRANSCRIPTS)
    MixpanelPeopleWorker.perform_async(user.email, {'$montly_usage' => usage, '$last_updated' => Time.now})
  end

end
