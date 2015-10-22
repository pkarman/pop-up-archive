class Organization < ActiveRecord::Base

  include Billable

  resourcify :is_resource_of

  # known bug with resourcify and rolify together
  # https://github.com/RolifyCommunity/rolify/issues/244
  # so we pass explicit association name to resourcify and let
  # rolify use the 'roles' association name.
  rolify

  attr_accessible :name

  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'

  has_many :users
  has_many :collection_grants, as: :collector
  has_many :collections, through: :collection_grants

  has_many :monthly_usages, as: :entity

  scope :premium_usage_desc, -> { order "cast(transcript_usage_cache->'premium_seconds' as int) desc" }
  scope :premium_usage_asc,  -> { order "cast(transcript_usage_cache->'premium_seconds' as int) asc"  }

  ROLES = [:admin, :member]

  # returns Array of User objects where the user's organization_id is not (yet) set
  # but where the user has an un-accepted invitation to join the org
  def invited_users
    User.where(invited_by_id: self.id, invited_by_type: 'Organization', invitation_accepted_at: nil) 
  end

  def invite_user(user)
    return if user.organization # already in org
    user.invited_by_id = self.id
    user.invited_by_type = 'Organization'
    user.invitation_token = Utils.generate_rand_str
    if user.send_org_invitation(self)
      user.save!
    end
    user
  end

  def delete_user(user)
    if user.organization
      user.organization_id = nil
    elsif user.invited_by_id
      user.invited_by_id = nil
    end
    user.save!
  end

  # entity method makes an Org act like a User for billable concern
  def entity
    self
  end

  def has_grant_for?(coll)
    collection_grants.each do |cg|
      if cg.collection_id == coll.id
        return true
      end
    end
    return false
  end

  def plan
    owner ? owner.plan : SubscriptionPlanCached.community
  end

  def pop_up_hours
    plan.hours
  end

  def owner_contact
    owner ? sprintf("%s <%s>", owner.name, owner.email) : '(nil)'
  end

  def set_amara_team(options={})
    options    = amara_team_defaults.merge(options)
    amara_team = find_or_create_amara_team(options)
    update_attribute(:amara_team, amara_team.slug)
  end

  def find_or_create_amara_team(options)
    amara_team = amara_client.teams.get(options[:slug]) rescue nil
    unless amara_team
      response = amara_client.teams.create(options)
      amara_team = response.object
    end
    amara_team
  end

  def amara_team_defaults
    {
      name: self.name,
      slug: self.name.parameterize,
      is_visible: false,
      membership_policy: Amara::TEAM_POLICIES[:invite]
    }
  end

  def amara_client
    Amara::Client.new(
    api_key:      amara_key || ENV['AMARA_KEY'],
    api_username: amara_username || ENV['AMARA_USERNAME'],
    endpoint:     "https://#{ENV['AMARA_HOST']}/api2/partners"
    )
  end

  def used_metered_storage
    @_used_metered_storage ||= billable_collections.map{|coll| coll.used_metered_storage}.inject(:+) || 0
  end

  def used_unmetered_storage
    @_used_unmetered_storage ||= billable_collections.map{|coll| coll.used_unmetered_storage}.inject(:+) || 0
  end

  def update_usage_report!
    update_attribute :used_metered_storage_cache, used_metered_storage
    update_attribute :used_unmetered_storage_cache, used_unmetered_storage
    update_attribute :transcript_usage_cache, transcript_usage_report
  end

  def self.get_org_ids_for_transcripts_since(since_dtim=nil)
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
    grants_sql      = "select g.collector_id from collection_grants as g where g.collector_type='Organization' and g.collection_id in (#{colls_sql})"
    #puts grants_sql

    org_ids = []
    pgres = User.connection.execute(grants_sql)
    pgres.each_row do |row|
      org_ids << row.first
    end
    return org_ids
  end

  # assigns the org to the user,
  # gives Org access to all the User's collections,
  # sets Org as billable owner of all User's collections.
  def add_to_team(user)
    # cannot assign an already-assigned user because user.billable_collections
    # might refer to the other org.
    if user.organization_id
      raise "Cannot assign user #{user.id} to org #{self.id} with add_to_team -- use user.organization_id directly"
    end

    # get billable collections first, since after we assign org, user.collections == org.collections
    colls = user.billable_collections
    user.organization_id = self.id
    user.save!
    colls.each do |coll|
      if coll.items.size == 0
        # empty collections are simply soft-deleted
        coll.destroy
        next
      end
      self.collections << coll
      coll.set_owner(self)
    end
    user
  end

end
