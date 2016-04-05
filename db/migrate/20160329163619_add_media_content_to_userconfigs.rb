class AddMediaContentToUserconfigs < ActiveRecord::Migration
  def change
    add_column :userconfigs, :media_content, :boolean
  end
end
