module Billable
  extend ActiveSupport::Concern

  # mixin methods for User and Organization for billing/usage

  # retail hourly rate (dollars)
  OVERAGE_HOURLY_RATE = 22

  def billable_collections
    # assumes every Collection is already assigned an owner.
    # this is done on Collection.create
    Collection.with_deleted.with_role(:owner, self)
  end

  # returns Array of AudioFile records
  def billable_audio_files
    billable_collection_ids = billable_collections.map { |c| c.id.to_s }
    return [] unless billable_collection_ids.size > 0
    items_sql = "select i.id from items as i where i.collection_id in (#{billable_collection_ids.join(',')})"
    audio_files_sql = "select * from audio_files as af where af.duration is not null and af.item_id in (#{items_sql})"
    AudioFile.find_by_sql(audio_files_sql)
  end

  # unlike normal audio_files association, which includes all records the User/Org is authorized to see,
  # my_audio_files limits to only those files where user_id=user.id
  # currently only supports User.
  def my_audio_files
    if self.is_a?(Organization)
      raise "Currently my_audio_files() only available to User class. You called on #{self.inspect}"
    end
    collection_ids = collections.map { |c| c.id.to_s }
    return [] unless collection_ids.size > 0

    items_sql = "select i.id from items as i where i.deleted_at is null and i.collection_id in (#{collection_ids.join(',')})"

    # NOTE we ignore whether duration is set or not. This is different than in transcript_usage definition below.
    audio_files_sql = "select * from audio_files as af where af.deleted_at is null and af.user_id=#{self.id}"
    AudioFile.find_by_sql(audio_files_sql)
  end

  # returns a hash with string values suitable for hstore
  def total_transcripts_report(ttype=:basic)

    # for now, we have only two types. might make sense
    # longer term to store the ttype on the transcriber record.
    case ttype
    when :basic
      usage_type = MonthlyUsage::BASIC_TRANSCRIPT_USAGE
      billable_type = MonthlyUsage::BASIC_TRANSCRIPTS
    when :premium
      usage_type = MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE
      billable_type = MonthlyUsage::PREMIUM_TRANSCRIPTS
    end

    # sum all the monthly usage
    total_secs          = monthly_usages.sum(:value)
    total_billable_secs = monthly_usages.where(use: billable_type).sum(:value)
    total_usage_secs    = monthly_usages.where(use: usage_type).sum(:value)
    total_cost          = monthly_usages.sum(:cost)
    total_retail_cost   = monthly_usages.sum(:retail_cost)
    total_billable_cost = monthly_usages.where(use: billable_type).sum(:cost)
    total_billable_retail_cost = monthly_usages.where(use: billable_type).sum(:retail_cost)
    total_usage_cost    = monthly_usages.where(use: usage_type).sum(:cost)
    total_usage_retail_cost = monthly_usages.where(use: usage_type).sum(:retail_cost)

    # we make seconds and cost fixed-width so that sorting a string works
    # like sorting an integer.
    return { 
      :seconds          => "%010d" % total_secs, 
      :cost             => sprintf('%010.2f', total_cost),
      :retail_cost      => sprintf('%010.2f', total_retail_cost),
      :billable_seconds => "%010d" % total_billable_secs,
      :billable_cost    => sprintf('%010.2f', total_billable_cost),
      :billable_retail_cost => sprintf('%010.2f', total_billable_retail_cost),
      :usage_seconds    => "%010d" % total_usage_secs,
      :usage_cost       => sprintf('%010.2f', total_usage_cost),
      :usage_retail_cost => sprintf('%010.2f', total_usage_retail_cost),
    }
  end

  # # returns SQL string for selecting the Transcript objects in the given time period and transcriber
  # def sql_for_billable_transcripts_for_month_of(dtim=DateTime.now, transcriber_id)

  #   # hand-roll sql to optimize query.
  #   # there might be a way to do this all with activerecord but my activerecord-fu is weak.
  #   month_start = dtim.utc.beginning_of_month
  #   month_end = dtim.utc.end_of_month
  #   start_dtim = month_start.strftime('%Y-%m-%d %H:%M:%S')
  #   end_dtim   = month_end.strftime('%Y-%m-%d %H:%M:%S')

  #   billable_collection_ids = billable_collections.map { |c| c.id.to_s }

  #   # return a non-matching query if we have 0 collections.
  #   # this satisfies chained callers.
  #   return "select * from transcripts where id < 0" unless billable_collection_ids.size > 0

  #   # transcriber_id may be an array
  #   tids = transcriber_id
  #   if transcriber_id.is_a?(Array)
  #     tids = transcriber_id.join(',')
  #   end

  #   items_sql = "select i.id from items as i where i.collection_id in (#{billable_collection_ids.join(',')})"
  #   audio_files_sql = "select af.id from audio_files as af where af.duration is not null and af.item_id in (#{items_sql})"
  #   transcripts_sql = "select * from transcripts as t where t.transcriber_id in (#{tids}) and t.audio_file_id in (#{audio_files_sql})"
  #   transcripts_sql += " and t.created_at between '#{start_dtim}' and '#{end_dtim}'"
  #   transcripts_sql += " and t.is_billable=true"
  #   transcripts_sql += " order by t.created_at asc"
  #   return transcripts_sql
  # end

  # this returns transcript usage by user or organization for a given month based on transcriber id
  # paid transcriber ids are 2 and 3
  def find_transcripts_usage_for_month_of(dtim=DateTime.now, transcriber_id)

    month_start = dtim.utc.beginning_of_month
    month_end = dtim.utc.end_of_month
    start_dtim = month_start.strftime('%Y-%m-%d %H:%M:%S')
    end_dtim   = month_end.strftime('%Y-%m-%d %H:%M:%S')

    # # NOTE we use collections, not billable_collections.
    collection_ids = collections.pluck(:id)

    # return a non-matching query if we have 0 collections.
    # this satisfies chained callers.
    return "select * from transcripts where id < 0" unless collection_ids.size > 0

    # transcriber_id may be an array
    tids = transcriber_id
    if transcriber_id.is_a?(Array)
      tids = transcriber_id.join(',')
    end

    items_sql = "select i.id from items as i where i.collection_id in (#{collection_ids.join(',')})"
    if self.is_a?(Organization)
      audio_files_sql = "select af.id from audio_files as af where af.duration is not null and af.item_id in (#{items_sql})"
    else
      audio_files_sql = "select af.id from audio_files as af where af.user_id=#{self.id} and af.duration is not null and af.item_id in (#{items_sql})"
    end

    transcripts_sql = "select * from transcripts as t where t.transcriber_id in (#{tids}) and t.audio_file_id in (#{audio_files_sql})"
    transcripts_sql += " and t.created_at between '#{start_dtim}' and '#{end_dtim}'"
    transcripts_sql += " and t.is_billable=true"
    transcripts_sql += " order by t.created_at asc"
    return transcripts_sql
  end

  # limit (optional) should be a DateTime object
  def transcript_usage(limit=nil)
    # keyed by yyyy-mm in chron order
    usage = {}

    # no limit == all usage
    if !limit
      # use monthly_usages as a shortcut for "all the months"
      monthly_usages.each do |mu|
        usage[mu.yearmonth] = [] unless usage.has_key?(mu.yearmonth)
        mu.transcripts.each do |tr|
          af = tr.audio_file_lazarus
          usage[mu.yearmonth].push tr.as_usage_summary(af)
        end
      end
    else
    # apply limit for one month only
      trs = []
      transcriber_ids = Transcriber.select(['id']).map(&:id)
      sql = self.find_transcripts_usage_for_month_of(limit, transcriber_ids)
      Transcript.find_by_sql(sql).each do |tr|
        af = tr.audio_file_lazarus
        trs.push tr.as_usage_summary(af)
      end
      usage[limit.strftime('%Y-%m')] = trs
    end

    usage
  end

  # unlike total_transcripts_report, transcripts_billable_for_month_of returns hash of numbers not strings.
  def transcripts_billable_for_month_of(dtim=DateTime.now, transcriber_id)
    total_secs = 0
    total_cost = 0
    total_retail_cost = 0
    
    sql = find_transcripts_usage_for_month_of(dtim, transcriber_id)
    Transcript.find_by_sql(sql).each do |tr|
      af = tr.audio_file_lazarus
      total_secs += tr.billable_seconds(af)
      total_cost += tr.cost(af)
      total_retail_cost += tr.retail_cost(af)
    end

    # cost_per_min is in 1000ths of a dollar, not 100ths (cents)
    # but we round to the nearest penny when we cache it in aggregate.
    return { :seconds => total_secs, :cost => total_cost.fdiv(1000), :retail_cost => total_retail_cost.fdiv(1000) }
  end

  # unlike transcripts_billable_for_month_of, this method looks at usage only, ignoring billable_to.
  # we do, however, pay attention to whether the audio_file is linked directly, so this method is really
  # only useful (at the moment) for User objects, esp Users belonging to an Organization.
  def transcripts_usage_for_month_of(dtim=DateTime.now, transcriber_id)
    total_secs = 0 
    total_cost = 0 
    total_retail_cost = 0 

    sql = find_transcripts_usage_for_month_of(dtim, transcriber_id)
    Transcript.find_by_sql(sql).each do |tr|
      af = tr.audio_file_lazarus
      total_secs += tr.billable_seconds(af)
      total_cost += tr.cost(af)
      total_retail_cost += tr.retail_cost(af)
    end

    # cost_per_min is in 1000ths of a dollar, not 100ths (cents)
    # but we round to the nearest penny when we cache it in aggregate.
    return { :seconds => total_secs, :cost => total_cost.fdiv(1000), :retail_cost => total_retail_cost.fdiv(1000) }
  end  

  def usage_for(use, now=DateTime.now)
    monthly_usages.where(use: use, year: now.utc.year, month: now.utc.month).sum(:value)
  end 

  def update_usage_for(use, rep, now=DateTime.now)
    monthly_usages.where(use: use, year: now.utc.year, month: now.utc.month).first_or_initialize.update_attributes!(value: rep[:seconds], cost: rep[:cost], retail_cost: rep[:retail_cost])
  end 

  def calculate_monthly_usages!
    months = (DateTime.parse(created_at.to_s)<<1 .. DateTime.now).select{ |d| d.strftime("%Y-%m-01") if d.day.to_i == 1 } 
    months.each do |dtim|
      ucalc = UsageCalculator.new(self, dtim)
      ucalc.calculate(MonthlyUsage::BASIC_TRANSCRIPTS)
      ucalc.calculate(MonthlyUsage::PREMIUM_TRANSCRIPTS)

      # calculate non-billable usage if the current actor is a User in an Org
      if self.is_a?(User) and self.entity != self
        ucalc.calculate(MonthlyUsage::BASIC_TRANSCRIPT_USAGE)
        ucalc.calculate(MonthlyUsage::PREMIUM_TRANSCRIPT_USAGE)
      end
    end 
  end 

  def owns_collection?(coll)
    has_role?(:owner, coll)
  end 

  def transcript_usage_report
    return {
      :basic_seconds => used_basic_transcripts[:seconds],
      :basic_cost => used_basic_transcripts[:cost],
      :basic_billable_seconds => used_basic_transcripts[:billable_seconds],
      :basic_billable_cost => used_basic_transcripts[:billable_cost],
      :basic_usage_seconds => used_basic_transcripts[:usage_seconds],
      :basic_usage_cost => used_basic_transcripts[:usage_cost],
      :premium_seconds => used_premium_transcripts[:seconds],
      :premium_cost => used_premium_transcripts[:cost],
      :premium_billable_seconds => used_premium_transcripts[:billable_seconds],
      :premium_billable_cost => used_premium_transcripts[:billable_cost],
      :premium_usage_seconds => used_premium_transcripts[:usage_seconds],
      :premium_usage_cost => used_premium_transcripts[:usage_cost],
    }   
  end 

  def used_basic_transcripts
    @_used_basic_transcripts ||= total_transcripts_report(:basic)
  end

  def used_premium_transcripts
    @_used_premium_transcripts ||= total_transcripts_report(:premium)
  end

  # Returns JSON-ready hash of monthly usage, including on-demand charges.
  # NOTE that for the purposes of billing, we ignore the 'cost' and 'retail_cost'
  # of the monthly usage records and instead look at (a) overages and (b) ondemand (premium usage on a basic plan).
  # The one exception is that we use the 'retail_cost' for case (b) since that is derived directly from
  # the transcripts themselves, unlike overages, which use a constant OVERAGE_HOURLY_RATE.
  def usage_summary(now=DateTime.now)
    summary = { 
      this_month: { secs: 0, hours: 0, overage: {}, ondemand: {}, cost: 0.00 },  
      current: [], 
      history: [], 
    }   
    year = now.utc.year
    month = now.utc.month
    thismonth = sprintf("%d-%02d", year, month)
    summary[:this_month][:period] = thismonth
    monthly_usages.order('"yearmonth" desc, "use" asc').slice(0,48).each do |mu|
      msum = { 
        period: mu.yearmonth,
        type:   mu.use,
        secs:   mu.value.to_i,
        hours:  mu.value.fdiv(3600).round(3),
        cost:   mu.retail_cost.round(2),  # expose only what we charge customers, whether we charge them or not.
      }
      summary[:history].push msum
      if mu.yearmonth == thismonth
        summary[:current].push msum
      end 
    end 

    # calculate current totals based on the User's plan. This determines overages.
    plan_hours        = plan.hours
    base_monthly_cost = plan.amount  # TODO??
    plan_is_premium   = plan.has_premium_transcripts?

    # if plan is "basic", calculate ondemand premium and overages.
    if !plan_is_premium 
      summary[:current].each do |msum|

        # if there is premium usage, it must be on-demand, so pass on the msum cost. 
        if msum[:type] == MonthlyUsage::PREMIUM_TRANSCRIPTS && msum[:hours] > 0 
          summary[:this_month][:ondemand][:cost]  = msum[:cost]
          summary[:this_month][:ondemand][:hours] = msum[:hours].round(3)
          summary[:this_month][:cost]            += msum[:cost]
          summary[:this_month][:hours]           += msum[:hours].round(3)
          summary[:this_month][:secs]            += msum[:secs]

        # basic plan, basic usage. 
        elsif msum[:type] == MonthlyUsage::BASIC_TRANSCRIPTS

           # month-to-date hours
           summary[:this_month][:hours] += msum[:hours].round(3)
           summary[:this_month][:secs]  += msum[:secs]

           # check for overage
           if msum[:hours] > plan_hours
             summary[:this_month][:overage][:hours] = msum[:hours] - plan_hours
             # we do not charge for basic plan overages. instead we just prevent them at upload time.
             #summary[:this_month][:overage][:cost] = (OVERAGE_HOURLY_RATE * summary[:this_month][:overage][:hours]).round(2)
             #summary[:this_month][:cost] += summary[:this_month][:overage][:cost]
           end
        end
      end

    # otherwise, plan is premium. sum this month and check for overages only.
    else
      summary[:current].each do |msum|
        summary[:this_month][:hours] += msum[:hours].round(3)
        summary[:this_month][:secs]  += msum[:secs]
        summary[:this_month][:cost]  += msum[:cost]

        if msum[:type] == MonthlyUsage::PREMIUM_TRANSCRIPTS
          if msum[:hours] > plan_hours
            summary[:this_month][:overage][:hours] = msum[:hours] - plan_hours
            summary[:this_month][:overage][:cost] = (OVERAGE_HOURLY_RATE * summary[:this_month][:overage][:hours]).round(2)
            summary[:this_month][:cost] += summary[:this_month][:overage][:cost]
          end
        end
      end
      if summary[:this_month][:overage][:cost]
        # since we had an overage for the month, ignore any specific retail costs for this month,
        # and treat the overage as the total for the month. This is because we don't want to charge 2x
        # if an on-demand retail cost contributed to the overage.
        summary[:this_month][:cost] = summary[:this_month][:overage][:cost]
      end
    end

    # return
    summary
  end

  def is_over_monthly_limit?
    self.entity.hours_remaining <= 0.0
  end

  def prorated_charge_for_month(dtim)
    # get number of days active in the month
    days_in_month = dtim.end_of_month.strftime('%d').to_i
    #STDERR.puts "days_in_month=#{days_in_month}"
    active_days = days_in_month - self.created_at.strftime('%d').to_i
    #STDERR.puts "active_days=#{active_days}"

    # get cost-per-day
    # Stripe reports amount in cents, so we convert to dollars.
    cost_per_day = (self.plan.amount / 100).fdiv(days_in_month)
    #STDERR.puts "cost_per_day=#{cost_per_day}"
    if self.plan.interval == 'year'
      cost_per_day = (self.plan.amount / 100).fdiv(365)
      #STDERR.puts "cost_per_day=#{cost_per_day} [yearly charge]"
    end 

    # multiply
    cost_per_day * active_days
  end 

  # returns number of hours (float) in the current billing cycle.
  # NOTE that for Community plan users the current billing cycle == eternity.
  def hours_remaining
    if self.entity.plan.is_community?
      self.entity.pop_up_hours - self.entity.premium_community_transcripts_usage.fdiv(3600)
    else
      self.entity.pop_up_hours - self.entity.premium_noncommunity_transcripts_usage.fdiv(3600)
    end 
  end

  # if user upgrades from community plan return usage for portion of month where
  # subscription plan was community
  def premium_community_transcripts_usage
    comm_plan_id = SubscriptionPlanCached.community.as_plan.id
    return if plan.id == comm_plan_id
    premium_ids = Transcriber.ids_for_type('premium')
    total_secs = 0
    sql = find_transcripts_usage_for_month_of(DateTime.now, premium_ids)
    return unless sql
    Transcript.find_by_sql(sql).each do |tr|
      next unless tr.subscription_plan_id == comm_plan_id
      af = tr.audio_file_lazarus
      total_secs += tr.billable_seconds(af)
    end
    total_secs
  end

  # returns total transcript duration for current month
  # for non-community subscription plans.
  def premium_noncommunity_transcripts_usage(dtim=DateTime.now)
    comm_plan_id = SubscriptionPlanCached.community.as_plan.id
    premium_ids = Transcriber.ids_for_type('premium')
    sql = find_transcripts_usage_for_month_of(dtim, premium_ids)

    # abort early if we have no transcripts
    return 0 if !sql

    total_secs = 0
    Transcript.find_by_sql(sql).each do |tr|
      next if tr.subscription_plan_id == comm_plan_id
      af = tr.audio_file_lazarus
      total_secs += tr.billable_seconds(af)
    end 
    total_secs
  end

  # def my_audio_file_storage(metered=true)
  #   total_secs = 0
  #   my_audio_files.each do |af|
  #     next unless af.duration
  #     if af.metered == metered
  #       total_secs += af.duration
  #     end
  #   end
  #   return total_secs
  # end

  # def get_total_seconds(ttype)
  #   ttype_s = ttype.to_s
  #   methname = 'used_' + ttype_s + '_transcripts'
  #   if transcript_usage_cache.has_key?(ttype_s+'_seconds')
  #     return transcript_usage_cache[ttype_s+'_seconds'].to_i
  #   else
  #     return send(methname)[:seconds].to_i
  #   end
  # end

  # def get_total_cost(ttype)
  #   ttype_s = ttype.to_s
  #   methname = 'used_' + ttype_s + '_transcripts'
  #   if transcript_usage_cache.has_key?(ttype_s+'_cost')
  #     return transcript_usage_cache[ttype_s+'_cost'].to_f
  #   else
  #     return send(methname)[:cost].to_f
  #   end
  # end

  # def is_within_sight_of_monthly_limit?
  #   summ      = self.entity.usage_summary
  #   threshold = (plan.hours * 0.85).to_f
  #   if summ[:this_month][:hours] > threshold
  #     return true
  #   else
  #     return false
  #   end
  # end

  # def send_usage_alert
  #   subject = 'ALERT: Your Pop Up Archive usage is nearing its limit'
  #   summ = self.entity.usage_summary
  #   plan_hours = plan.hours
  #   body    = sprintf("You have used %d (%d%%) of your monthly limit of %d hours.", \
  #               summ[:this_month][:hours], ((summ[:this_month][:hours] / plan_hours) * 100), plan_hours)
  #   MyMailer.usage_alert(subject, body, self.entity.owner.email).deliver
  # end

  # def hours_used_in_month(dtim=DateTime.now)
  #   secs = 0 
  #   this_month = dtim.strftime('%Y-%m')
  #   monthly_usages.where(yearmonth: this_month).each do |mu|
  #     secs += mu.value
  #   end 
  #   secs.fdiv(3600)
  # end

end
