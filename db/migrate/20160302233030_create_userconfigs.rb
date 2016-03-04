class CreateUserconfigs < ActiveRecord::Migration
  def change
    create_table :userconfigs do |t|
      t.string :username
      t.string :date
      t.string :company
      t.string :logo_url
      t.string :home_url
      t.string :vault
      t.string :resources
      t.string :onboarding_tasks
      t.string :medical_credentialing
      t.string :loan_origination
      t.string :upload_sign
      t.string :tax_return
      t.string :submit_claim

      t.timestamps
    end
  end
end
