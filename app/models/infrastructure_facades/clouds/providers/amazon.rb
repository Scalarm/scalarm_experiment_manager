require_relative 'infrastructure_facades/clouds/abstract_cloud_client'

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

    def create_instances(base_name, image_id, number)
      # list of AbstractVmInstance
    end


    ## -- VM instance methods --

    def name(id)
      # String: name of virtual machine instance
    end

    def state(id)
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