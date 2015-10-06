module Box

  if ENV['JWT_PRIVATE_KEY_PATH']
    PRIVATE_KEY = File.read(Rails.root.join(ENV['JWT_PRIVATE_KEY_PATH']))
  else
    PRIVATE_KEY = ENV['JWT_PRIVATE_KEY']
  end

  TOKEN_TTL = 45.minutes

  def self.admin_client
    access_token = admin_token
    Boxr::Client.new(access_token)
  end

  def self.user_client(user_id)
    access_token = user_token(user_id)
    Boxr::Client.new(access_token)
  end

  def self.admin_token
    access_token = Rails.cache.fetch("box_tokens/enterprise/#{ENV['BOX_ENTERPRISE_ID']}", :expires_in => TOKEN_TTL) do
      puts "getting new enterprise token"
      response = Boxr::get_enterprise_token(private_key: PRIVATE_KEY, private_key_password: ENV['JWT_PRIVATE_KEY_PASSWORD'])
      response.access_token
    end
  end

  def self.user_token(user_id)
    access_token = Rails.cache.fetch("box_tokens/user/#{user_id}", :expires_in => TOKEN_TTL) do
      puts "getting new user token"

      response = Boxr::get_user_token(user_id, private_key: PRIVATE_KEY, private_key_password: ENV['JWT_PRIVATE_KEY_PASSWORD'])
      response.access_token
    end
  end

end
