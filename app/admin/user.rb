ActiveAdmin.register User do
  actions :index, :show
  index do
    column :name, sortable: :name do |user|
      link_to( user.name, superadmin_user_path(user) ) + raw( '<br/>' + user.email )
    end
    column :last_sign_in_at
    column 'Plan', :subscription_plan_id, sortable: :subscription_plan_id do |user|
      user.plan.name + ' [' + (user.subscription_plan_id.to_s||'(nil)') + ']'
    end
    column 'Usage', :premium_seconds, sortable: "transcript_usage_cache->'premium_seconds'" do |user|
      raw 'Premium: ' + \
      Api::BaseHelper::time_definition(user.transcript_usage_report[:premium_billable_seconds].to_i||0) + \
      '&nbsp;' + number_to_currency(user.transcript_usage_report[:premium_billable_cost].to_f||'0.00') + \
      '<br/>' + \
      'Basic: ' + \
      Api::BaseHelper::time_definition(user.transcript_usage_report[:basic_billable_seconds].to_i||0) + \
      '&nbsp;' + number_to_currency(user.transcript_usage_report[:basic_billable_cost].to_f||'0.00')
    end
    column 'Switch', sortable: false do |user|
      link_to( user.email, "/su?scope_identifier=user_#{user.id}" )
    end
  end

  filter :email
  filter :name
  filter :organization

  show do
    panel "User Details" do
      attributes_table_for user do
        row("ID") { user.id }
        row("Name") { user.name }
        row("Email") { link_to( user.email, "/su?scope_identifier=user_#{user.id}" ) + raw(' &#171; switch') }
        row("Organization") {
          user.organization_id \
          ? (link_to user.organization.name, superadmin_organization_path(user.organization)) \
          : span(('none'), class: "empty")
        }
        #row("Metered Storage") { Api::BaseHelper::time_definition(user.used_metered_storage_cache||0) }
        #row("Unmetered Storage") { Api::BaseHelper::time_definition(user.used_unmetered_storage_cache||0) }
        row("Plan") { user.plan.name + ' ' + user.plan.hours.to_s + 'h (billed per ' + user.plan.interval + ')' }
        row("Premium Plan") { user.plan.has_premium_transcripts? }
        #row("Total Premium Transcripts (Billable)") { Api::BaseHelper::time_definition(user.transcript_usage_report[:premium_billable_seconds].to_i||0) }
        #row("Total Premium Cost (Billable)") { number_to_currency(user.transcript_usage_report[:premium_billable_cost].to_f||'0.00') }
        #row("Total Basic Transcripts (Billable)") { Api::BaseHelper::time_definition(user.transcript_usage_report[:basic_billable_seconds].to_i||0) }
        #row("Total Basic Cost (Billable)") { number_to_currency(user.transcript_usage_report[:basic_billable_cost].to_f||'0.00') }
        row("Last Sign In") { user.last_sign_in_at }
        row("Sign In Count") { user.sign_in_count }
        row("Created") { user.created_at }
        row("Updated") { user.updated_at }
      end
    end

    panel "Monthly Usage" do
      table_for user.monthly_usages.where(use: ["basic transcripts", "premium transcripts"]).order('yearmonth desc') do |tbl|
        tbl.column('Month') {|mu| link_to mu.yearmonth, superadmin_monthly_usage_path(mu) }
        tbl.column :use
        tbl.column('Wholesale') {|mu| div :class => "cost" do number_to_currency(mu.cost); end }
        tbl.column('Retail') {|mu| div :class => "cost" do number_to_currency(mu.retail_cost); end }
        tbl.column('Time') {|mu| Api::BaseHelper::time_definition(mu.value||0) }
      end
    end

    panel "Authorized Collections" do
      table_for user.collections do|tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Storage Type") {|coll| coll.storage }
        tbl.column("Items") {|coll| link_to "#{coll.items.count} Items", :action => 'index', :controller => "items", q: { collection_id_equals: coll.id.to_s } }
      end
    end

    panel "Billable Collections" do
      table_for user.billable_collections do|tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Storage Type") {|coll| coll.storage }
        tbl.column("Items") {|coll| link_to "#{coll.items.count} Items", :action => 'index', :controller => "items", q: { collection_id_equals: coll.id.to_s } } 
      end 
    end

    panel "Owned Organizations" do
      table_for user.owned_organizations do|tbl|
        tbl.column :id
        tbl.column("Name") {|org| link_to org.name, superadmin_organization_path(org) }
        tbl.column("Metered Storage") {|org| Api::BaseHelper::time_definition(org.used_metered_storage_cache||0) }
        tbl.column("Unmetered Storage") {|org| Api::BaseHelper::time_definition(org.used_unmetered_storage_cache||0) }
      end
    end

    active_admin_comments
  end

end
