class AddExtraToCollection < ActiveRecord::Migration
  def change
    add_column :collections, :extra, :hstore
  end
end
