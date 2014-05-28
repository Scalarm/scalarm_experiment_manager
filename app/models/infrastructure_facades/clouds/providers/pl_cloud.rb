require 'infrastructure_facades/clouds/abstract_cloud_client'
require 'infrastructure_facades/pl_cloud_utils/pl_cloud_util'
require 'infrastructure_facades/pl_cloud_utils/pl_cloud_util_instance'

module PLCloud

  class CloudClient < AbstractCloudClient
    def initialize(secrets)
      super(secrets)
      @plc_util = PLCloudUtil.new(secrets)
    end

    def self.short_name
      'pl_cloud'
    end

    def self.long_name
      'PLGrid Cloud'
    end

    def all_images_info
      Hash[@plc_util.all_images_info.map {|id, info| [id, info['NAME']]}]
    end

    def all_vm_ids
      @plc_util.all_vm_info.keys.map {|i| i.to_s}
    end

    def instantiate_vms(base_name, image_id, number, params)
      @plc_util.create_instances(base_name, image_id, number)
    end

    ## -- VM instance methods --

    STATES_MAPPING = {
        'INIT'=> :initializing,
        'PENDING'=> :initializing,
        'HOLD'=> :error,
        'ACTIVE'=> :running,
        'STOPPED'=> :deactivated,
        'SUSPENDED'=> :deactivated,
        'DONE'=> :deactivated,
        'FAILED'=> :error,
        'POWEROFF'=> :deactivated,
        'UNDEPLOYED'=> :deactivated
    }

    def status(id)
      STATES_MAPPING[
        PLCloudUtilInstance::VM_STATES[@plc_util.vm_info(id)['STATE'].to_i]
      ]
    end

    def terminate(id)
      @plc_util.delete_instance(id)
    end

    def reinitialize(id)
      @plc_util.resubmit(id)
    end

    def public_ssh_address(id)
      # String: public host of VM -- dynamically gets hostname from API
      vmi = @plc_util.vm_instance(id)
      vmi.redirections[22] or vmi.redirect_port(22)
    end

    def vm_record_info(vm_record)
      ''
    end

    def instance_types
      {
          'standard'=> 'Standard (0.5 CPU, 512 MB RAM, x86_64)'
      }
    end

  end

end