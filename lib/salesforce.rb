module Salesforce
  def self.salesforce_admin
    client = Restforce.new :username => ENV['SALESFORCE_USERNAME'],
      :password       => ENV['SALESFORCE_PASSWORD'],
      :security_token => ENV['SALESFORCE_SECURITY_TOKEN'],
      :client_id      => ENV['CONSUMER_KEY'],
      :client_secret  => ENV['CONSUMER_SECRET']
  end
end
