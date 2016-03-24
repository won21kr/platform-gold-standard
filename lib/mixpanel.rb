module Mixpanel

	def self.client
		Mixpanel::Tracker.new('ENV['MIXPANEL_TOKEN']')
	end
end
