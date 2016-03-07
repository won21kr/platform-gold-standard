class CreateUserconfigs < ActiveRecord::Migration
  def change
    create_table :userconfigs do |t|
      t.text :username
      t.datetime :date
      t.text :company
      t.text :logo_url
      t.text :home_url
      t.boolean :vault
      t.boolean :resources
      t.boolean :onboarding_tasks
      t.boolean :medical_credentialing
      t.boolean :loan_origination
      t.boolean :upload_sign
      t.boolean :tax_return
      t.boolean :submit_claim

      t.timestamps
    end
  end
end
