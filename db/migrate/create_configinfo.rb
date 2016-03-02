class ConfigInfo < ActiveRecord::Migration
  def change
    create_table :configinfo do |t|
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

    # weekday_employee = Login.new(employee_id: '1234', password: 'demo1234', box_user_id: '253207142', name: 'Chris Huff', schedule: '1 2 3 4 5')
    # weekday_employee.save

    # weekend_employee = Login.new(employee_id: '4321', password: 'demo1234', box_user_id: '243438677',
    #                               name: 'Gwenda Keen', schedule: '6 0')
    # weekend_employee.save
    #
    # store_manager = Login.new(employee_id: '5678', password: 'demo1234', box_user_id: '255067618', name: 'Sophie Irvine', schedule: '0 1 2 3 4 5 6')
    # store_manager.save
  end
end
