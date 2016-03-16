class CreateTabUsages < ActiveRecord::Migration
  def change
    create_table :tab_usages do |t|
      t.integer :vault
      t.integer :resources
      t.integer :onboarding_tasks
      t.integer :medical_credentialing
      t.integer :loan_origination
      t.integer :upload_sign
      t.integer :tax_return
      t.integer :submit_claim

      t.timestamps
    end
  end
end
