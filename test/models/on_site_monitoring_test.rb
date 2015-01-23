require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class OnSiteMonitoringTest < MiniTest::Test

  def test_pinged_recently_true
    osm_record = OnSiteMonitoring.new(
        last_ping: Time.now # fake first ping
    )

    assert osm_record.pinged_recently?
  end

end