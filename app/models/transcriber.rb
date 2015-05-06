class Transcriber < ActiveRecord::Base

  # IMPORTANT: cost_per_min is in 1000ths of a dollar, not 100ths (cents)
  # so e.g. $0.062 is recorded as 62
  attr_accessible :name, :cost_per_min, :url, :description, :retail_cost_per_min

  has_many :transcripts

  after_commit :invalidate_caches, on: :update

  def self.basic
    @_basic ||= self.find_by_name('google_voice')
  end

  def self.premium
    @_premium ||= self.find_by_name('speechmatics')
  end

  def self.voicebase
    @_voicebase ||= self.find_by_name('voicebase')
  end

  # call this whenever making price changes
  def invalidate_caches
    @_basic = nil
    @_premium = nil
  end

  # returns float for cost of N seconds of transcription.
  # NOTE cost_per_min is wholesale cost, not retail cost.
  def wholesale_cost(seconds)
    mins = seconds.to_i.fdiv(60)
    c = (cost_per_min.to_f * mins.to_f) / 1000
    c.round(2)
  end

  # returns float for retail cost of N seconds of transcription.
  def retail_cost(seconds)
    mins = seconds.to_i.fdiv(60)
    c = (retail_cost_per_min.to_f * mins.to_f) / 1000
    c.round(2)
  end

end
