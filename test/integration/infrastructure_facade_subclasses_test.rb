require 'csv'
require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class InfrastructureFacadeSubclassesTest < Test::Unit::TestCase

  def setup
  end

  FACADE_CLASSES = {
      plgrid: PlGridFacade,
      private_machine: PrivateMachineFacade,
      pl_cloud: CloudFacade,
      amazon: CloudFacade,
      google: CloudFacade
  }

  FACADE_METHODS = [
      :short_name,
      :long_name,
      :default_additional_params,
      :start_simulation_managers,
      # :clean_tmp_credentials, # ?
      # :current_state, # ?
      :add_credentials,
      :remove_credentials, # !
      :get_sm_records,
      :create_simulation_manager
  ]

  SM_METHODS = [
      :simulation_manager_terminate,
      :simulation_manager_running?,
      :simulation_manager_get_log,
      :simulation_manager_restart,
      :simulation_manager_status
  ]

  def test_get_registered_infrastructures
    # given, when
    infrastructures_hash = InfrastructureFacade.get_registered_infrastructures

    # then
    assert_equal FACADE_CLASSES.count, infrastructures_hash.count
    FACADE_CLASSES.each do |id, facade_class|
      assert infrastructures_hash.has_key?(id), "not registered infrastrucuture: #{id}"
      assert infrastructures_hash[id].has_key?(:facade), "no facade for #{id}"
      assert_equal facade_class, infrastructures_hash[id][:facade].class, id.to_s
    end
  end

  def test_subclasses_implementation
    # given
    infrastructure_facades = InfrastructureFacade.get_registered_infrastructures.values.map {|i| i[:facade]}

    # when, then
    assert_nothing_thrown do
      infrastructure_facades.each do |facade|
        assert FACADE_METHODS.each {|method| assert facade.respond_to?(method), "no method #{method} in #{facade}"}
      end
    end
  end

end