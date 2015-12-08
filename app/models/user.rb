require 'customer'

class User < ActiveRecord::Base

  include Billable
  include ActionView::Helpers::NumberHelper

  rolify
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :provider, :uid, :name

  belongs_to :organization
  belongs_to :subscription_plan

  after_validation :customer #ensure that a stripe customer has been created
  after_destroy :delete_customer
  after_commit :add_default_collection, on: :create

  has_many :collection_grants, as: :collector
  has_many :collections, -> { includes :default_storage }, through: :collection_grants
  has_many :items, through: :collections
  has_many :audio_files, through: :items
  has_many :csv_imports
  has_many :charges
  has_many :oauth_applications, class_name: 'Doorkeeper::Application', as: :owner

  has_many :active_admin_comments, as: :resource

  has_many :monthly_usages, as: :entity

  has_many :owned_organizations, class_name: 'Organization', foreign_key: 'owner_id'

  validates_presence_of :name, if: :name_required?

  OVERAGE_CALC = 'coalesce(used_metered_storage_cache - pop_up_hours_cache * 3600, 0)'

  scope :over_limits, -> { select("users.*, #{OVERAGE_CALC} as overage").where("#{OVERAGE_CALC} > 0").order('overage DESC') }
  scope :premium_usage_desc, -> { order "cast(transcript_usage_cache->'premium_seconds' as int) desc" }
  scope :premium_usage_asc,  -> { order "cast(transcript_usage_cache->'premium_seconds' as int) asc"  }

  delegate :name, :id, :amount, to: :plan, prefix: true

  def self.find_for_oauth(auth, signed_in_resource=nil)
    where(provider: auth.provider, uid: auth.uid).first ||
    create{|user| user.apply_oauth(auth)}
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.oauth_data"]
        user.provider = data['provider']
        user.uid      = data['uid']
        user.email    = data["email"] if user.email.blank?
        user.name     = data["name"] if user.name.blank?
        user.valid?   if data[:should_validate]
      end
    end
  end

  def apply_oauth(auth)
    self.provider = auth.provider
    self.uid      = auth.uid
    self.name     = auth.info.name
    self.email    = auth.info.email
  end

  def password_required?
    # logger.debug "password_required? checked on #{self.inspect}\n"
    !provider.present? && !@skip_password && super
  end

  def name_required?
    # logger.debug "name_required? checked on #{self.inspect}\n"
    !provider.present? && !@skip_password && !name.present?
  end

  def searchable_collection_ids
    collection_ids
  end

  def to_s
    email
  end

  # all_items is different than items relationship because it uses
  # the overridden collections method to reflect org assignments.
  def all_items
    all_items = []
    collections.each do |c|
      c.items.each do |i|
        all_items.push i
      end
    end
    all_items
  end

  def collections
    organization ? organization.collections : super
  end

  def collection_ids
    organization ? organization.collection_ids : super
  end

  def collections_title_id
    colls = {}
    collections_without_my_uploads.each do |c|
      colls[c.id.to_s] = c.title
    end
    colls
  end

  def collections_without_my_uploads
    collections
  end

  def in_organization?
    !!organization_id
  end

  # rolify gem version > 3.2.0 "conveniently" caches roles instead of going back to the db each time,
  # and the caching algorithm does not include any invalidation when add_role() is called.
  # so we just skip their caching altogether by overriding has_role?() method here.
  def has_role?(role_name, resource = nil)
    has_role_helper(role_name, resource)
  end

  # everyone is considered an admin on their own, role varies for those in orgs
  def role
    return :admin unless organization
    if has_role?(:admin, organization)
      return :admin
    elsif organization.owner_id == self.id
      return :owner
    else
      return :member
    end
  end

  def billable_subscription_plan_id
    if organization && organization.owner
      organization.owner.subscription_plan_id
    else
      subscription_plan_id
    end
  end

  def super_admin?
    has_role?(:super_admin)
  end

  def update_card!(card_token)
    cus = customer.stripe_customer
    cus.card = card_token
    cus.save
    invalidate_cache
    @_customer = nil
  end

  def subscribe!(plan, offer = nil)
    # plan is_a SubscriptionPlanCached object
    cus = customer.stripe_customer
    subscr = customer.stripe_subscription(cus)
    # we should always have a baseline subscription at stripe, no matter what.
    if !subscr
      customer.subscribe_to_community
      cus = customer.stripe_customer
      subscr = customer.stripe_subscription(cus)
    end
    subscr.metadata[:orig_start] = subscr.metadata[:start]
    if (offer == 'radiorace')
      subscr.plan = plan.id
      subscr.metadata[:offer_end] = 30.days.from_now.to_i
    else
      # see https://github.com/popuparchive/pop-up-archive/issues/1011
      # initial sign-up has "trial" until the first day of the next month.
      #
      # set up params based on some scenarios:
      #
      # these are API defaults; we just make them explicit
      trial_end = nil
      prorate   = false
      orig_plan = subscr.plan # isa Stripe::Plan
      ####################################################################
      # new customer setting non-community subscription for the first time
      if (!customer.stripe_customer || customer.in_first_month?) && plan.is_community?
        trial_end = customer.class.end_of_this_month
      end

      ###########################################################################
      # existing customer still inside initial "trial" month before first billing
      if customer.in_first_month? && !plan.is_community?
        trial_end = customer.class.end_of_this_month
      end

      #######################################################
      # existing customer after first billing (regular cycle)
      if !customer.in_first_month?
        subscr.metadata[:existing] = true
        subscr.metadata[:is_community] = plan.is_community?
        # keep trial alive if currently trialing
        if subscr.status == 'trialing'
          trial_end = customer.class.end_of_this_month
        end
        # if moving from community to non-community, treat like trial
        if (orig_plan.id == "premium_community" || orig_plan.name == "1 Hour Demo") && !plan.is_community?
          trial_end = customer.class.end_of_this_month
        end
      end 

      subscr.plan = plan.id
      subscr.coupon = offer if (offer && offer.length)
      subscr.trial_end = trial_end if trial_end
      subscr.prorate = prorate
      subscr.metadata[:prorate]   = prorate
      subscr.metadata[:trial_end] = trial_end
      subscr.metadata[:coupon]    = offer
      subscr.metadata[:in_first_month] = customer.in_first_month?
      subscr.metadata[:is_community]   = plan.is_community?
      subscr.metadata[:offer_end]     = nil
    end

    # custom metadata, including start time (so we can test effectively)
    subscr.metadata[:start] ||= Time.now.utc.to_i
    subscr.metadata[:updated] = Time.now.utc.to_i

    # write change
    subscr.save

    # log it
    if subscr.plan.id != orig_plan.id
      MixpanelWorker.perform_async(self.email, 'subscription change', { customer: customer_id, orig_plan: orig_plan.name, new_plan: subscr.plan.name })
      MixpanelPeopleWorker.perform_async(self.email, {'$plan' => subscr.plan.id})
    end

    # must do this manually after subscription.save has successfully completed
    # so that our local caches are in sync.
    sp = SubscriptionPlan.find_by_stripe_plan_id(plan.id)
    update_attribute :subscription_plan_id, sp.id if persisted?

    invalidate_cache
    @_customer = nil
  end

  def add_invoice_item!(invoice_item)
    cus = customer.stripe_customer
    cus.add_invoice_item(invoice_item)
  end

  def plan
    if organization && (organization.owner_id != id)
      return organization.plan || SubscriptionPlanCached.community
    elsif subscription_plan_id.present?
      return subscription_plan.as_cached || SubscriptionPlanCached.community
    else
      return customer.plan || SubscriptionPlanCached.community
    end
  end

  def charges
    if organization && organization.owner_id != self.id
      puts "Using organization.owner.charges"
      organization.owner.charges
    else
      super
    end
  end

  def populate_charges
    # fetch Stripe transactions and sync with charges table
    # start with invoices
    invoices = Stripe::Invoice.all(customer: customer_id)
    invoices.each do |inv|
      charge = Charge.find_by_ref_id inv.id
      amt = inv.lines.first.amount
      # skip empty invoices
      next if amt.to_i == 0
      if !charge
        charge = Charge.create(ref_id: inv.id, ref_type: 'invoice', transaction_at: Time.at(inv.date), amount: amt.fdiv(100))
        self.charges << charge
      end
    end

    # charges
    str_charges = Stripe::Charge.all(customer: customer_id)
    str_charges.each do |chrg|
      charge = Charge.find_by_ref_id(chrg.id) || Charge.find_by_ref_id(chrg.invoice)
      if !charge
        charge = Charge.create(ref_id: chrg.id, ref_type: 'charge', transaction_at: Time.at(chrg.created), amount: chrg.amount.fdiv(100), extras: { invoice: chrg.invoice } )
        self.charges << charge
      end
    end

    # refunds, refer only to parent Stripe charges
    self.charges.each do |charge|
      next unless charge.ref_type == 'charge'
      refunds = Stripe::Refund.all(charge: charge.ref_id)
      refunds.each do |refund|
        ref_charge = Charge.find_by_ref_id(refund.id)
        if !ref_charge
          ref_charge = Charge.create(ref_id: refund.id, ref_type: 'refund', transaction_at: Time.at(refund.created), amount: refund.amount.fdiv(100), extras: { charge: refund.charge, reason: refund.reason })
          self.charges << ref_charge
        end
      end
    end

    self.save!

  end

  def entity
    @_entity ||= organization || self
  end

  def owner
    if organization
      organization.owner
    else
      self
    end
  end

  def plan_json
    {
      name: plan.name,
      id: plan.id,
      amount: plan.amount,
      pop_up_hours: plan.hours,
      trial: customer.trial,  # TODO cache this better to avoid needing to call customer() at all.
      offer_end: offer_end(),
      interim: customer.is_interim_trial?,
      interval: plan.interval,
      is_premium: plan.has_premium_transcripts? ? true : false,
    }
  end

  def offer_end
    cus = customer.stripe_customer
    subscr = customer.stripe_subscription(cus)
    return nil unless subscr
    offer_end=subscr.metadata[:offer_end].to_i || nil
    if offer_end > 0
      Time.at(offer_end)
    else
      nil
    end
  end

  def is_offer_ended?
    return false unless offer_end()
    return offer_end() <= Time.now
  end

  def send_org_invitation(org)
    r = OrganizationMemberInviteMailer.new_invite(org, self).deliver_now
    self.invitation_sent_at = DateTime.now.utc
    self.invitation_accepted_at = nil
    self
  end

  def org_invite_url(org)
    Rails.application.routes.url_helpers.root_url + 'organization/' + org.id.to_s + '/member/' + self.invitation_token
  end

  def confirm_org_member_invite(org)
    return if invitation_accepted_at
    return unless invitation_sent_at
    return unless invited_by_id == org.id
    return unless invited_by_type == 'Organization'
    self.add_to_team(org)
    self.invitation_accepted_at = DateTime.now.utc
    self.save!
  end

  def customer
    return @_customer if !@_customer.nil?
    return unless self.email
    begin
      cache_ttl = Rails.application.config.stripe_cache
    rescue
      cache_ttl = 5.minutes
    end
    if customer_id.present?
      Rails.cache.fetch([:customer, :individual, customer_id], expires_in: cache_ttl) do
        stripe_cust = Customer.get_stripe_customer(customer_id)
        cus = nil
        if stripe_cust
          cus = Customer.new(stripe_cust)
          # update our local cache to point at the current plan
          sp = SubscriptionPlan.find_by_stripe_plan_id(cus.plan.id)
          update_attribute :subscription_plan_id, sp.id if persisted?
        else
          cus = Customer.generic_community
        end
        @_customer = cus
        cus
      end
    else

      return unless persisted?

      # check first if customer with this email was created in the last 10 minutes
      # to avoid dupe creation. We can't search by email, so must just list limited by time.
      Stripe::Customer.all(created: { gte: Time.now.to_i - 600 }).tap do |custs| 
        custs.each do |cust|
          if cust.email == self.email
            self.customer_id = cust.id
            update_attribute :customer_id, cust.id if persisted?
            @_customer = Customer.new(cust)
            Rails.cache.write([:customer, :individual, cust.id], @_customer, expires_in: cache_ttl)
            sp = SubscriptionPlan.find_by_stripe_plan_id(@_customer.plan_id||SubscriptionPlanCached.community.id)
            update_attribute :subscription_plan_id, sp.id if persisted?
          end
        end
      end
      return @_customer if @_customer
      
      # go ahead and create
      Customer.new(Stripe::Customer.create(email: email, description: name)).tap do |cus|
        #STDERR.puts cus.inspect
        #STDERR.puts cus.stripe_customer.inspect
        self.customer_id = cus.id
        update_attribute :customer_id, cus.id if persisted?
        Rails.cache.write([:customer, :individual, cus.id], cus, expires_in: cache_ttl)
        sp = SubscriptionPlan.find_by_stripe_plan_id(cus.plan_id||SubscriptionPlanCached.community.id)
        update_attribute :subscription_plan_id, sp.id if persisted?
        @_customer = cus
      end
    end
  end

  def pop_up_hours
    plan.hours
  end

  def used_metered_storage
    @_used_metered_storage ||= billable_collections.map{|coll| coll.used_metered_storage}.inject(:+) || 0
  end

  def used_unmetered_storage
    @_used_unmetered_storage ||= billable_collections.map{|coll| coll.used_unmetered_storage}.inject(:+) || 0
  end

  def active_credit_card_json
    active_credit_card.as_json.try(:slice, *%w(last4 type exp_month exp_year))
  end

  # if this user is in an organization and not the owner, use the owner's credit card.
  # otherwise, use the user's customer record.
  def active_credit_card
    if organization && (organization.owner_id != id) && organization.owner
      return organization.owner.active_credit_card
    else
      customer.card
    end
  end

  def has_active_credit_card?
    active_credit_card.has_key?("last4")
  end

  def update_usage_report!
    update_attribute :used_metered_storage_cache, used_metered_storage
    update_attribute :used_unmetered_storage_cache, used_unmetered_storage
    update_attribute :pop_up_hours_cache, pop_up_hours
    update_attribute :transcript_usage_cache, transcript_usage_report
  end

  def self.get_user_ids_for_transcripts_since(since_dtim=nil)
    if since_dtim == nil
      since_dtim = DateTime.now - (1/24.0)  # an hour ago
    elsif since_dtim.is_a?(DateTime)
      # no op
    else
      since_dtim = DateTime.parse(since_dtim)
    end

    #puts "Checking transcripts modified since #{since_dtim}"

    transcripts_sql = "select t.audio_file_id from transcripts as t where t.updated_at >= '#{since_dtim.strftime('%Y-%m-%d %H:%M:%S')}'"
    audio_files_sql = "select a.item_id from audio_files as a where a.deleted_at is null and a.id in (#{transcripts_sql})"
    items_sql       = "select i.collection_id from items as i where i.deleted_at is null and i.id in (#{audio_files_sql})"
    colls_sql       = "select c.creator_id from collections as c where c.deleted_at is null and c.id in (#{items_sql})"
    grants_sql      = "select g.collector_id from collection_grants as g where g.collector_type='User' and g.collection_id in (#{colls_sql})"
    #puts grants_sql

    user_ids = []
    pgres = User.connection.execute(grants_sql)
    pgres.each_row do |row|
      user_ids << row.first
    end
    return user_ids
  end

  def invalidate_cache
    Rails.cache.delete(customer_cache_id)
    @_customer = nil
  end

  def can_admin_org?
    return false unless self.organization_id
    return true if self.organization.owner_id == self.id
    return true if self.has_role?(:admin, self.organization)
    return false
  end

  def is_over_monthly_limit?
    if organization
      organization.is_over_monthly_limit?
    else
      super
    end
  end

  def add_to_team(org)
    org.add_to_team(self)
  end

  def self.created_in_month(dtim=DateTime.now)
    month_start = dtim.utc.beginning_of_month
    month_end = dtim.utc.end_of_month
    start_dtim = month_start.strftime('%Y-%m-%d %H:%M:%S')
    end_dtim   = month_end.strftime('%Y-%m-%d %H:%M:%S')
    sql = "select * from users where created_at between '#{start_dtim}' and '#{end_dtim}' order by created_at desc"
    User.find_by_sql(sql)
  end

  def is_new_in_month?(dtim=DateTime.now)
    month_start = dtim.utc.beginning_of_month
    month_end   = dtim.utc.end_of_month
    if self.created_at < month_end and self.created_at > month_start
      return true
    else
      return false
    end
  end

  private

  def delete_customer
    return true unless customer
    return true unless customer.stripe_customer
    customer.stripe_customer.delete
    invalidate_cache
  end

  def customer_cache_id
    [:customer, :individual, customer_id]
  end

  def add_default_collection
    title = "#{name}'s Collection"
    collection = Collection.new(title: title, creator: self, items_visible_by_default: false)
    collection.save!
    collection
  end

end
