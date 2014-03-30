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
      amazon: CloudFacade
  }

  FACADE_METHODS = [
      :monitoring_loop,
      :default_additional_params,
      :start_simulation_managers,
      :clean_tmp_credentials,
      :all_sm_records_for,
      :current_state,
      :add_credentials,
      :short_name,
      :to_hash,
      :get_sm_containers
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