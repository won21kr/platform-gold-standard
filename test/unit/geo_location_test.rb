require 'test_helper'

class GeoLocationTest < ActiveSupport::TestCase
  def test_should_be_valid
    assert GeoLocation.new.valid?
  end
end
