class IpAddress < ActiveRecord::Base
    attr_accessible :ip_address, :latitude, :longtitude
    geocoded_by :ip_address
    after_validation :geocode
end
