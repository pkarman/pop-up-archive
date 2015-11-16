ActiveAdmin.register Organization do
  actions :index, :show
  index do
    column :name, sortable: :name do |org| 
      link_to( org.name, superadmin_organization_path(org)) + raw('<br/>') + org.owner_contact
    end
    column :plan do |org| (org.owner_id && org.owner.plan) ? org.owner.plan.name : span('(none)', class: "empty") end
    column 'Usage', :premium_seconds, sortable: "transcript_usage_cache->'premium_seconds'" do |org|
      raw 'Premium: ' + \
      Api::BaseHelper::time_definition(org.transcript_usage_report[:premium_billable_seconds].to_i||0) + \
      '&nbsp;' + number_to_currency(org.transcript_usage_report[:premium_billable_cost].to_f||'0.00') + \
      '<br/>' + \
      'Basic: ' + \
      Api::BaseHelper::time_definition(org.transcript_usage_report[:basic_billable_seconds].to_i||0) + \
      '&nbsp;' + number_to_currency(org.transcript_usage_report[:basic_billable_cost].to_f||'0.00')
    end
  end

  filter :name

  show do
    panel "Organization Details" do
      attributes_table_for organization do
        row("ID") { organization.id }
        row("Name") { organization.name }
        row("Owner") { organization.owner_id ? (link_to organization.owner.name, superadmin_user_path(organization.owner)) : span(I18n.t('active_admin.empty'), class: "empty") }
        row("Plan") do |org|
          if org.owner
            plan = org.owner.plan
            plan.name + ' ' + plan.hours.to_s + 'h (billed per ' + plan.interval + ')'
          else
            span(I18n.t('active_admin.empty'), class: "empty")
          end
        end
        row("Premium Plan") do |org| org.owner ? org.owner.plan.has_premium_transcripts? : false end
        #row("Metered Storage") { Api::BaseHelper::time_definition(organization.used_metered_storage_cache||0) }
        #row("Unmetered Storage") { Api::BaseHelper::time_definition(organization.used_unmetered_storage_cache||0) }
        #row("Total Premium Transcripts (Billable)") { Api::BaseHelper::time_definition(organization.transcript_usage_report[:premium_billable_seconds].to_i||0) }
        #row("Total Premium Cost (Billable)") { number_to_currency(organization.transcript_usage_report[:premium_billable_cost].to_f||'0.00') }
        #row("Total Basic Transcripts (Billable)") { Api::BaseHelper::time_definition(organization.transcript_usage_report[:basic_billable_seconds].to_i||0) }
        #row("Total Basic Cost (Billable)") { number_to_currency(organization.transcript_usage_report[:basic_billable_cost].to_f||'0.00') }
        row("Created") { organization.created_at }
        row("Updated") { organization.updated_at }
      end
    end
    panel "Monthly Usage" do
      table_for organization.monthly_usages.order('yearmonth desc') do|tbl|
        tbl.column('Month') {|mu| link_to mu.yearmonth, superadmin_monthly_usage_path(mu) }
        tbl.column :use
        tbl.column('Wholesale') {|mu| div :class => "cost" do number_to_currency(mu.cost); end }
        tbl.column('Retail') {|mu| div :class => "cost" do number_to_currency(mu.retail_cost); end }
        tbl.column('Time') {|mu| mu.value_as_hms }
      end
    end
    panel "Users" do
      table_for organization.users do |tbl|
        tbl.column("Name") {|user| link_to user.name, superadmin_user_path(user) }
        tbl.column("Email") {|user| link_to( user.email, "/su?scope_identifier=user_#{user.id}" ) + raw(' &#171; switch')  }
        tbl.column("Last Sign In") {|user| user.last_sign_in_at }
        #tbl.column("Metered Storage") {|user| Api::BaseHelper::time_definition(user.used_metered_storage_cache||0) }
        #tbl.column("Unmetered Storage") {|user| Api::BaseHelper::time_definition(user.used_unmetered_storage_cache||0) }
        tbl.column("Role") {|user| user.role }
      end
    end
    panel "Authorized Collections" do
      table_for organization.collections do |tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Created By") {|coll| coll.creator ? link_to(coll.creator, superadmin_user_path(coll.creator)) : nil }
        tbl.column("Storage Type") {|coll| coll.storage }
        tbl.column("Items") {|coll| link_to "#{coll.items.count} Items", :action => 'index', :controller => "items", q: { collection_id_equals: coll.id.to_s } }
      end
    end
    panel "Billable Collections" do
      table_for organization.billable_collections do |tbl|
        tbl.column("Title") {|coll| link_to coll.title, superadmin_collection_path(coll) }
        tbl.column("Created") {|coll| coll.created_at }
        tbl.column("Created By") {|coll| coll.creator ? link_to(coll.creator, superadmin_user_path(coll.creator)) : nil }
        tbl.column("Storage Type") {|coll| coll.storage }
        tbl.column("Items") {|coll| link_to "#{coll.items.count} Items", :action => 'index', :controller => "items", q: { collection_id_equals: coll.id.to_s } } 
      end 
    end

    active_admin_comments
  end

end
