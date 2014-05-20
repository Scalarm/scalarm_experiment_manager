require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

require 'infrastructure_facades/cloud_facade'
require 'infrastructure_facades/plgrid/grid_schedulers/glite'
require 'infrastructure_facades/plgrid/grid_schedulers/pbs'
require 'infrastructure_facades/private_machine_facade'

class SimulationManagersContainersSubclassesTest < Test::Unit::TestCase

  def setup
  end

  SUBCLASSES = {
      pl_cloud: CloudFacade,
      amazon: CloudFacade,
      private_machine: PrivateMachineFacade,
      glite: GliteFacade,
      qsub: PBSFacade
  }

  METHODS = [
      :get_container_sm_record,
      :get_container_all_sm_records,
      :get_container_simulation_manager,
      :get_container_all_simulation_managers,
      :long_name,
      :short_name
  ]

  def test_get_registered_sm_containers
    # given, when
    sm_container_hash = InfrastructureFacade.get_registered_sm_containters

    # then
    assert_equal SUBCLASSES.count, sm_container_hash.count, sm_container_hash
    SUBCLASSES.each do |id, sm_container_class|
      assert sm_container_hash.has_key?(id), sm_container_hash.to_s #"not registered sm_container: #{id}, #{sm_container_hash.map{|i,c| "#{i} -> #{c.class}"}}"
      assert_equal sm_container_hash[id].class, sm_container_class, "invalid class for sm_container: #{id} -> #{sm_container_class}"
    end
  end

  def test_subclasses_implementation
    # given
    sm_containers = InfrastructureFacade.get_registered_sm_containters.values

    # when, then
    assert_nothing_thrown do
      sm_containers.each do |sm_container|
        assert METHODS.each {|method| assert sm_container.respond_to?(method), "no method #{method} in #{sm_container}"}
      end
    end
  end

end