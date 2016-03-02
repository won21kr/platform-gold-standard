class Configinfo < ActiveRecord::Base
  ACCESSIBLE_ATTRIBUTES = [:username, :date, :company, :logo_url, :home_url,
                           :vault, :resources, :onboarding_tasks, :medical_credentialing,
                           :loan_origination, :upload_sign, :tax_return, :submit_claim]
  attr_accessible *ACCESSIBLE_ATTRIBUTES

  validates_presence_of :username, :date, :company, :logo_url, :home_url,
                        :vault, :resources, :onboarding_tasks, :medical_credentialing,
                        :loan_origination, :upload_sign, :tax_return, :submit_claim
end
