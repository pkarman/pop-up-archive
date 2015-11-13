ActiveAdmin.register Transcript do
  actions :index, :show
  menu false
  index do
    column :audio_file
    #column :identifier
    #column :language 
    column :created_at 
    column :billable_to, :sortable => false
    column :transcriber
    column('Wholesale Cost') do |t| number_to_currency(t.cost_dollars) end
    column('Retail Cost') do |t| number_to_currency(t.retail_cost_dollars) end
  end

  filter :transcriber

  show do 
    panel "Transcript Details" do
      attributes_table_for transcript do
        row :id
        row("PUA URL") {transcript.audio_file.item.url}
        row :transcriber
        row :audio_file
        row :identifier
        row :created_at
        row :updated_at
        row :start_time
        row :end_time
        row("User") { user = transcript.audio_file_lazarus.user; user ? link_to(user.name, superadmin_user_path(user)) : nil }
        row :billed_as
        row :billable_to
        row :billable_seconds
        row :is_billable
        row("Premium") { transcript.is_premium? }
        row("Wholesale Cost") { number_to_currency(transcript.cost_dollars) }
        row("Retail Cost") { number_to_currency(transcript.retail_cost_dollars) }
      end     
    end
 
    active_admin_comments
  end

end
