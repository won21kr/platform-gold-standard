class CreateGeoplaces < ActiveRecord::Migration
  def change
    create_table :geoplaces do |t|
      t.string :address
      t.float :latitude
      t.float :longtitude

      t.timestamps
    end
  end
end
