require 'infrastructure_facades/clouds/abstract_cloud_client'

module AmazonCloud

  class CloudClient < AbstractCloudClient

    def initialize(secrets)
      super(secrets)
      @ec2 = AWS::EC2.new(access_key_id: secrets.secret_access_key_id,
                          secret_access_key: secrets.secret_access_key)
    end

    def self.short_name
      'amazon'
    end

    def self.full_name
      'Amazon Elastic Compute Cloud'
    end

    def all_vm_ids
      @ec2.instances.map {|inst| inst.id}
    end

    def schedule_vm_instances(base_name, image_id, number, params)
      instances = @ec2.regions['us-east-1'].instances.create(:image_id => image_id,
                                  :count => number,
                                  :instance_type => params[:instance_type],
                                  :security_groups => [ params[:security_group] ])
      instances = [instances] if instances.kind_of?(Array)
      instances.map &:id
    end


    ## -- VM instance methods --

    STATES_MAPPING = {
      pending: :initializing,
      running: :running,
      shutting_down: :deactivated,
      terminated: :deactivated,
      stopping: :deactivated,
      stopped: :deactivated
    }

    def status(id)
      STATES_MAPPING[ec2_instance(id).status]
    end

    def terminate(id)
      ec2_instance(id).terminate
    end

    def reinitialize(id)
      ec2_instance(id).reboot
    end

    # @return [Hash] {:ip => string cloud public ip, :port => string redirected port} or nil on error
    def public_ssh_address(id)
      {ip: ec2_instance(id).public_dns_name, port: '22'}
    end

    def vm_record_info(vm_record)
      "Type: #{instance_type}"
    end

    def exists?(id)
      ec2_instance(id).exists?
    end

    # -- additional Amazon methods --

    def self.amazon_instance_types
      [
          ['Micro (Up to 2 EC2 Compute Units, 613 MB RAM)', 't1.micro'],
          ['Small (1 EC2 Compute Unit, 1.7 GB RAM)', "m1.small"],
      #['Medium (2 EC2 Compute Unit, 3.75 GB RAM)', "m1.medium"],
      # ["Large (4 EC2 Compute Unit, 1.7 GB RAM)", "m1.large"],
      # ["Extra Large (8 EC2 Compute Unit, 15 GB RAM)", "m1.xlarge"],
      #['High-CPU Medium (5 EC2 Compute Unit, 1.7 GB RAM)', "c1.medium"],
      #['High-CPU Extra Large (20 EC2 Compute Unit, 7 GB RAM)', "c1.xlarge"]
      ]
    end

    def ec2_instance(id)
      @ec2.instances[id]
    end

  end

end