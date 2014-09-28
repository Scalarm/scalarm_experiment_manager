require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/grid_schedulers/qsub'

class QsubTest < MiniTest::Test

  def setup
    @logger = stub_everything
    @qsub = QsubScheduler::PlGridScheduler.new(@logger)
  end

  def test_onsite_monitorable
    assert @qsub.onsite_monitorable?
  end

end