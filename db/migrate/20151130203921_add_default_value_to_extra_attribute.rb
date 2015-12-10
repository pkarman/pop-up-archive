class AddDefaultValueToExtraAttribute < ActiveRecord::Migration
  def change
  	change_column :collections, :extra, :hstore, :default => ''
  end
end
