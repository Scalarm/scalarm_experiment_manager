require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'sidekiq/testing'

class SimMonitorWorkerTest < MiniTest::Test

  def setup
    Sidekiq::Testing.fake!

    InfrastructureFacade.any_instance.stubs(:short_name).returns("")
    InfrastructureFacade.any_instance.stubs(:long_name).returns("")
    InfrastructureFacade.any_instance.stubs(:init_resources)
    InfrastructureFacade.any_instance.stubs(:clean_up_resources)
  end

  def test_nil_facade_handle
    InfrastructureFacadeFactory.stubs(:get_facade_for).returns(nil)


    worker = SimMonitorWorker.new
    worker.perform("", "")
  end

  def test_empty_simulation_manager_list
    fake_infrastructure = InfrastructureFacade.new
    fake_infrastructure.stubs(:get_sm_records).returns([])
    InfrastructureFacadeFactory.stubs(:get_facade_for).returns(fake_infrastructure)


    SimMonitorWorker.expects(:perform_in).never


    worker = SimMonitorWorker.new
    worker.perform("", "")
  end

  def test_monitoring_of_error_only_sims
    sim_1 = mock "" do
      stubs(:monitor)
      stubs(:state).returns(:error)
      stubs(:record).returns("This is fake record")
    end

    sim_2 = mock "" do
      stubs(:monitor)
      stubs(:state).returns(:error)
      stubs(:record).returns("This is fake record")
    end

    fake_infrastructure = InfrastructureFacade.new
    fake_infrastructure.stubs(:get_sm_records).returns([sim_1, sim_2])
    fake_infrastructure.stubs(:create_simulation_manager).with(sim_1).returns(sim_1)
    fake_infrastructure.stubs(:create_simulation_manager).with(sim_2).returns(sim_2)
    InfrastructureFacadeFactory.stubs(:get_facade_for).returns(fake_infrastructure)


    SimMonitorWorker.expects(:perform_in).never


    worker = SimMonitorWorker.new
    worker.perform("", "")
  end

  def test_monitoring_of_non_error_only_sims
    sim_1 = mock "" do
      stubs(:monitor)
      stubs(:state).returns(:created)
      stubs(:record).returns("This is fake record")
    end

    sim_2 = mock "" do
      stubs(:monitor)
      stubs(:state).returns(:error)
      stubs(:record).returns("This is fake record")
    end

    fake_infrastructure = InfrastructureFacade.new
    fake_infrastructure.stubs(:get_sm_records).returns([sim_1, sim_2])
    fake_infrastructure.stubs(:create_simulation_manager).with(sim_1).returns(sim_1)
    fake_infrastructure.stubs(:create_simulation_manager).with(sim_2).returns(sim_2)
    InfrastructureFacadeFactory.stubs(:get_facade_for).returns(fake_infrastructure)


    SimMonitorWorker.expects(:perform_in).once


    worker = SimMonitorWorker.new
    worker.perform("", "")
  end

  def test_sim_which_throws_exception
    sim_1 = mock "" do
      stubs(:monitor).raises(StandardError)
      stubs(:state).returns(:created)
      stubs(:record).returns("This is fake record")
    end

    fake_infrastructure = InfrastructureFacade.new
    fake_infrastructure.stubs(:get_sm_records).returns([sim_1])
    fake_infrastructure.stubs(:create_simulation_manager).with(sim_1).returns(sim_1)
    InfrastructureFacadeFactory.stubs(:get_facade_for).returns(fake_infrastructure)


    SimMonitorWorker.expects(:perform_in)


    worker = SimMonitorWorker.new
    worker.perform("", "")
  end

end
