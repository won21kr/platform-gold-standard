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

    entry = TabUsage.new(vault: 0, resources: 0, onboarding_tasks: 0,
                         medical_credentialing: 0, loan_origination: 0,
                         upload_sign: 0, tax_return: 0, submit_claim: 0)
    entry.save
  end
end
