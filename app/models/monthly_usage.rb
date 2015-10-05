class MonthlyUsage < ActiveRecord::Base

  belongs_to :entity, :polymorphic => true
  attr_accessible :entity, :entity_id, :entity_type, :month, :year, :use, :value, :yearmonth, :cost, :retail_cost

  PREMIUM_TRANSCRIPTS = 'premium transcripts'
  BASIC_TRANSCRIPTS   = 'basic transcripts'
  PREMIUM_TRANSCRIPT_USAGE = 'premium (usage only)'
  BASIC_TRANSCRIPT_USAGE   = 'basic (usage only)'

  before_save :set_yearmonth

  def set_yearmonth
    self.yearmonth = sprintf("%d-%02d", year, month)
  end

  # return the transcripts that match the current entity + yearmonth
  def transcripts
    # finding the transcriber id is the most brittle.
    # TODO something better than string matching-by-convention
    # (though that does seem to be the Rails Way)
    usage_type = use.match(/^(\w+)/)[0]
    transcriber_id = Transcriber.ids_for_type(usage_type)
    ymd = DateTime.parse(self.yearmonth + '-01')
    if entity_type == 'User' && use.match(/usage only/)
      transcripts = entity.find_transcripts_usage_for_month_of(ymd, transcriber_id)
    else
      sql = entity.sql_for_billable_transcripts_for_month_of(ymd, transcriber_id)
      transcripts = Transcript.find_by_sql(sql)
    end
    transcripts
  end

  def value_as_hms
    Time.at(self.value).getgm.strftime('%H:%M:%S')
  end

end
