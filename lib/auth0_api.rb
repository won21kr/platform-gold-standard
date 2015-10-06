module Auth0API
  def self.client
    Auth0Client.new(
      :client_id => ENV['AUTH0_CLIENT_ID'],
      :client_secret => ENV['AUTH0_CLIENT_SECRET'],
      :namespace => ENV['AUTH0_DOMAIN']
    )
  end
end