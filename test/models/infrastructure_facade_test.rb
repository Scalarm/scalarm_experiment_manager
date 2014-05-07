require 'test/unit'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructureFacadeTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_get_facade_for_fail
    assert_raises InfrastructureErrors::NoSuchInfrastructureError do
      InfrastructureFacade.get_facade_for('something_new')
    end

    assert_raises InfrastructureErrors::NoSuchInfrastructureError do
      InfrastructureFacade.get_facade_for(nil)
    end
  end

  def test_monitoring_loop
    rec1 = mock('rec1') {
      expects(:should_destroy?).returns(false)
      stubs(:id).returns('1')
      expects(:destroy).never
    }
    rec2 = mock('rec2') {
      expects(:should_destroy?).returns(true)
      stubs(:id).returns('2')
      expects(:destroy).once
    }
    rec3 = mock('rec3') {
      expects(:should_destroy?).returns(false)
      stubs(:id).returns('3')
      expects(:destroy).never
    }

    sm1 = mock('sm1') {
      stubs(:record).returns(rec1)
      expects(:monitor).once
    }
    sm2 = mock('sm2') {
      stubs(:record).returns(rec2)
      expects(:monitor).raises(StandardError.new('test'))
    }
    sm3 = mock('sm3') {
      stubs(:record).returns(rec3)
      expects(:monitor).never
    }

    grouped_sm_records = {a: [rec1, rec2, rec3]}
    grouped_simulation_managers = {a: [sm1, sm2, sm3]}

    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)

    facade = PlGridFacade.new

    facade.stubs(:get_grouped_sm_records).returns(grouped_sm_records)
    facade.stubs(:get_grouped_simulation_managers).returns(grouped_simulation_managers)

    facade.monitoring_loop
  end
end