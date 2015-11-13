ActiveAdmin.register Item do
  actions :index, :show
  menu false
  index do
    column :title, sortable: :title do |item| link_to item.title, superadmin_item_path(item) end
    column :created_at
    column :duration
    column('Collection') do |item| link_to item.collection.title, superadmin_collection_path(item.collection) end
  end

  filter :title

  show do 
    panel "Item Details" do
      attributes_table_for item do
        row("ID") { item.id }
        row("PUA URL") {item.url}
        row("Identifier") { item.identifier }
        row("Token") { item.token }
        row("Language") { item.language }
        row("Title") { item.title }
        row("Collection") { link_to item.collection.title, superadmin_collection_path(item.collection) }
        row("Duration") { item.duration }
        # this is confusing to most people because it is only applied to on-demand uploads.
        #row("Transcript Type") { item.transcript_type }
        row("Created") { item.created_at }
        row("Updated") { item.updated_at }
      end     
    end
    panel "Audio Files" do
      table_for item.audio_files do |tbl|
        tbl.column("File") {|af| link_to (af.filename.present? ? af.filename : af.id), superadmin_audio_file_path(af) }
        tbl.column("Type") {|af| af.transcript_type }
        tbl.column("Transcoded") {|af| af.transcoded_at }
        tbl.column("Duration") {|af| af.duration }
        tbl.column("Status") {|af| af.current_status }
        tbl.column("Tasks") do |af| 
          link_to "#{af.tasks.count} tasks", :action => 'index', :controller => "tasks", q: { owner_id_equals: af.id.to_s, owner_type_equals: 'AudioFile' } 
        end 
      end     
    end
    panel "Image Files" do
      table_for item.image_files do |tbl|
        tbl.column("ID") {|imgf| imgf.id } 
        tbl.column("URL") {|imgf| imgf.url }
      end     
    end
 
    active_admin_comments
  end

end
