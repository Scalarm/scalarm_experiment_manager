require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructureFacadeTest < MiniTest::Test

  def setup
  end

  def teardown
  end

  def test_monitoring_loop_uncaugth_integration
    rec1 = stub_everything('rec1') {
      expects(:should_destroy?).returns(false)
      stubs(:id).returns('1')
      expects(:destroy).never
      expects(:monitoring_group).returns(:a).at_least_once
    }
    rec2 = stub_everything('rec2') {
      expects(:should_destroy?).returns(true)
      stubs(:id).returns('2')
      expects(:destroy).once
      expects(:monitoring_group).returns(:a).at_least_once
    }
    rec3 = stub_everything('rec3') {
      expects(:should_destroy?).returns(false)
      stubs(:id).returns('3')
      expects(:destroy).never
      expects(:monitoring_group).returns(:a).at_least_once
    }

    sm1 = stub_everything('sm1') {
      stubs(:record).returns(rec1)
      expects(:monitor).once
    }
    sm2 = stub_everything('sm2') {
      stubs(:record).returns(rec2)
      expects(:monitor).raises(StandardError.new('test'))
    }
    sm3 = stub_everything('sm3') {
      stubs(:record).returns(rec3)
      expects(:monitor).never
    }

    InfrastructureFacade.any_instance.stubs(:short_name).returns('a')
    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)
    facade = InfrastructureFacade.new

    facade.stubs(:create_simulation_manager).with(rec1).returns(sm1)
    facade.stubs(:create_simulation_manager).with(rec2).returns(sm2)
    facade.stubs(:create_simulation_manager).with(rec3).returns(sm3)

    facade.stubs(:get_sm_records).returns([rec1, rec2, rec3])

    facade.expects(:init_resources).once
    facade.expects(:clean_up_resources).once

    # execution
    facade.monitoring_loop
  end

  def test_grouping_methods
    rec1 = stub_everything('rec1') {
      stubs(:id).returns('1')
      expects(:monitoring_group).returns(:a).at_least_once
    }
    rec2 = stub_everything('rec2') {
      stubs(:id).returns('2')
      expects(:monitoring_group).returns(:a).at_least_once
    }
    rec3 = stub_everything('rec3') {
      stubs(:id).returns('3')
      expects(:monitoring_group).returns(:b).at_least_once
    }
    rec4 = stub_everything('rec4') {
      stubs(:id).returns('4')
      expects(:monitoring_group).returns(:c).at_least_once
    }

    sm1 = stub_everything('sm1') {
      stubs(:record).returns(rec1)
    }
    sm2 = stub_everything('sm2') {
      stubs(:record).returns(rec2)
    }
    sm3 = stub_everything('sm3') {
      stubs(:record).returns(rec3)
    }
    sm4 = stub_everything('sm4') {
      stubs(:record).returns(rec4)
    }

    InfrastructureFacade.any_instance.stubs(:short_name).returns('a')
    InfrastructureTaskLogger.stubs(:new).returns(stub_everything)
    facade = InfrastructureFacade.new

    facade.stubs(:create_simulation_manager).with(rec1).returns(sm1)
    facade.stubs(:create_simulation_manager).with(rec2).returns(sm2)
    facade.stubs(:create_simulation_manager).with(rec3).returns(sm3)
    facade.stubs(:create_simulation_manager).with(rec4).returns(sm4)

    facade.stubs(:get_sm_records).returns([rec1, rec2, rec3, rec4])


    # count groups
    grouped_records = facade.get_grouped_sm_records
    assert_equal 2, grouped_records[:a].count
    assert_equal 1, grouped_records[:b].count
    assert_equal 1, grouped_records[:c].count

    # are simulation managers group the same as records group?
    facade.yield_grouped_simulation_managers do |grouped_managers|
      grouped_managers.each do |manager_group, managers|
        assert_equal grouped_records[manager_group].map(&:id), managers.map {|sm| sm.record.id}
      end
    end
  end

end