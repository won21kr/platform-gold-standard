class CreateIpAddresses < ActiveRecord::Migration
  def change
    create_table :ip_addresses do |t|
      t.string :ip_address
      t.float :latitude
      t.float :longtitude

      t.timestamps
    end
  end
end
