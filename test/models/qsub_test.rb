require 'test/unit'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/grid_schedulers/qsub'

class QsubTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_minutes_to_walltime
    assert_equal '5:10', QsubScheduler::PlGridScheduler.minutes_to_walltime(310)
  end

end