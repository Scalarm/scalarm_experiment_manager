require_relative 'infrastructure_facades/clouds/abstract_cloud_client'
require 'infrastructure_facades/pl_cloud_utils/pl_cloud_util'

module PLCloud

  class CloudClient < AbstractCloudClient
    def initialize(secrets)
      super(secrets)

      @plc_util = PLCloudUtil.new(secrets)
    end

    def self.short_name
      'plcloud'
    end

    def self.full_name
      'PLGrid Cloud'
    end

    def all_vm_ids
      @plc_util.all_vm_info.keys
    end

    # TODO: think about return values and vm type (power)
    def create_instances(base_name, image_id, number)
      @plc_util.create_instances(base_name, image_id, number).map do |vm_id|
        vm_instance(vm_id)
      end
    end

    ## -- VM instance methods --

    def name(id)
      @plc_util.vm_info(id)['NAME']
    end

    def state(id)
      # - initializing (after creation and before running)
      # - running (booting and running)
      # - deactivated (after running - machine was send to stop, terminate or deletion)
      # - rebooting

      # one of: [:pending, :running, :shutting_down, :terminated, :stopping, :stopped]
    end

    def exists?(id)
      # true if VM exists (instance with given id is still available)
    end

    def terminate(id)
      # nil -- terminates VM
    end

    def public_host(id)
      # String: public host of VM -- dynamically gets hostname from API
    end

    def public_ssh_port(id)
      # String: public ssh port of VM -- dynamically gets hostname from API
    end

  end

end