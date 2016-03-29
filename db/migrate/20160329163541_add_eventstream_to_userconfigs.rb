class AddEventstreamToUserconfigs < ActiveRecord::Migration
  def change
    add_column :userconfigs, :eventstream, :boolean
  end
end
