require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class InfrastructureFacadeSubclassesTest < MiniTest::Test

  FACADE_CLASSES = {
      qsub: PlGridFacade,
      glite: PlGridFacade,
      qcg: PlGridFacade,
      private_machine: PrivateMachineFacade,
      pl_cloud: CloudFacade,
      amazon: CloudFacade,
      google: CloudFacade,
      dummy: DummyFacade
  }

  FACADE_METHODS = [
      :long_name,
      :short_name,
      :start_simulation_managers,
      :sm_record_class,
      :add_credentials,
      :remove_credentials,
      :get_credentials,
      :_get_sm_records,
      :get_sm_record_by_id,
      :enabled_for_user?
  ]

  SM_METHODS = [
      :_simulation_manager_stop,
      :_simulation_manager_restart,
      :_simulation_manager_resource_status,
      :_simulation_manager_get_log,
      :_simulation_manager_prepare_resource,
      :_simulation_manager_install,
      :_simulation_manager_before_monitor,
      :_simulation_manager_after_monitor
  ]

  def test_get_registered_infrastructures
    # given, when
    infrastructure_names = InfrastructureFacadeFactory.get_registered_infrastructure_names

    # then
    assert_equal FACADE_CLASSES.count, infrastructure_names.count
    FACADE_CLASSES.each do |id, facade_class|
      assert infrastructure_names.include?(id.to_s), "not registered infrastrucuture: #{id}; #{infrastructure_names}"
      assert !!InfrastructureFacadeFactory.get_facade_for(id), "no facade for #{id}"
      assert_equal facade_class, InfrastructureFacadeFactory.get_facade_for(id).class, id.to_s
    end
  end

  def test_subclasses_implementation
    # given
    infrastructure_facades = InfrastructureFacadeFactory.get_all_infrastructures

    # when, then
    infrastructure_facades.each do |facade|
      assert (FACADE_METHODS+SM_METHODS).each {|method| assert facade.respond_to?(method), "no method #{method} in #{facade}"}
    end
  end

end