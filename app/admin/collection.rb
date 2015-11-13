ActiveAdmin.register Collection do
  actions :index, :show
  index do
    column :title, sortable: :title do |coll| link_to coll.title, superadmin_collection_path(coll) end
    column :updated_at
    column :default_storage, sortable: :default_storage do |coll| coll.storage end
    column :creator do |coll| coll.creator ? link_to(coll.creator) : '(none)' end
  end

  filter :title

  show do 
    panel "Collection Details" do
      attributes_table_for collection do
        row("ID") { collection.id }
        row("PUA URL") {collection.url}
        row("Title") { collection.title }
        row("Creator") { collection.creator ? (link_to collection.creator.name, superadmin_user_path(collection.creator)) : nil }
        row("Billable To") { 
          if collection.billable_to.is_a?(User)
            link_to collection.billable_to.name, superadmin_user_path(collection.billable_to)
          else
            link_to collection.billable_to.name, superadmin_organization_path(collection.billable_to)
          end
        }
        row("Public")  { collection.items_visible_by_default }
        row("Storage") { collection.storage }
        row("Created") { collection.created_at }
        row("Updated") { collection.updated_at }
      end     
    end
    panel "Items (#{collection.items.count})" do
      table_for collection.items do|tbl|
        tbl.column("ID") {|item| item.id }
        tbl.column("Title") {|item| link_to item.title, superadmin_item_path(item) }
        tbl.column("Status") {|item| item.audio_files.first ? item.audio_files.first.current_status : 'n/a' }
        tbl.column("Created") {|item| item.created_at }
        tbl.column("Duration") {|item| item.duration }
        tbl.column("Public")   {|item| item.is_public }
      end
    end
   
    active_admin_comments
  end

end
