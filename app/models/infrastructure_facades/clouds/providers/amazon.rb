require 'infrastructure_facades/clouds/abstract_cloud_client'

module AmazonCloud

  class CloudClient < AbstractCloudClient

    def self.short_name
      'amazon'
    end

    def self.full_name
      'Amazon Elastic Compute Cloud'
    end

    def all_vm_ids
      # list of all vm instances ids
    end

    def schedule_vm_instances(base_name, image_id, number, params)
      # list of AbstractVmInstance
    end


    ## -- VM instance methods --

    def name(id)
      # String: name of virtual machine instance
    end

    def status(id)
      # one of: [:pending, :running, :shutting_down, :terminated, :stopping, :stopped]
    end

    def exists?(id)
      # true if VM exists (instance with given id is still available)
    end

    def terminate(id)
      # nil -- terminates VM
    end

    def reinitialize(id)
      # Amazon reboot
    end

    # @return [Hash] {:ip => string cloud public ip, :port => string redirected port} or nil on error
    def public_ssh_address(id)

    end

    def vm_record_info(vm_record)
      "Type: #{instance_type}"
    end

  end

end