module Mixpanel

	if Rails.env.development?
    # silence local SSL errors
    Mixpanel.config_http do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end

	def self.client
		Mixpanel::Tracker.new(ENV['MIXPANEL_TOKEN'])
	end
end
