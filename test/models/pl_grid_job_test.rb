require 'test/unit'
require 'test_helper'
require 'mocha'

class PlGridJobTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_queue_for_minutes
    assert_equal 'plgrid-testing', PlGridJob.queue_for_minutes(10)
    assert_equal 'plgrid-testing', PlGridJob.queue_for_minutes(30)

    assert_equal 'plgrid', PlGridJob.queue_for_minutes(70)
    assert_equal 'plgrid', PlGridJob.queue_for_minutes(5*60)

    assert_equal 'plgrid-long', PlGridJob.queue_for_minutes(72*60 + 3)
  end

  def test_queue
    assert_equal 'plgrid-testing', PlGridJob.new({time_limit: 30}).queue
    assert_equal 'plgrid', PlGridJob.new({time_limit: 100}).queue
    assert_equal 'plgrid-long', PlGridJob.new({time_limit: 80*60}).queue
  end

end