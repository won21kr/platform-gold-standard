class AddOktaToUserconfigs < ActiveRecord::Migration
  def change
    add_column :userconfigs, :okta, :boolean
  end
end
