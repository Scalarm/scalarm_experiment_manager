require 'infrastructure_facades/clouds/abstract_cloud_client'
require 'aws-sdk'

module AmazonCloud

  class CloudClient < AbstractCloudClient

    attr_reader :ec2

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

    def all_images_info
      Hash[@ec2.images.with_owner('self').map {|i| [i.image_id, i.name] }]
    end

    def all_vm_ids
      @ec2.instances.map(&:id)
    end

    def instantiate_vms(base_name, image_id, number, params)
      instances = @ec2.regions['us-east-1'].instances.create(:image_id => image_id,
                                  :count => number,
                                  :instance_type => params[:instance_type],
                                  :security_groups => [ params[:security_group] ])
      instances = [instances] unless instances.kind_of?(Array)
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
      {host: ec2_instance(id).public_dns_name, port: '22'}
    end

    def exists?(id)
      ec2_instance(id).exists?
    end

    def instance_types
      {
          't1.micro'=> 'Micro (Up to 2 EC2 Compute Units, 613 MB RAM)',
          'm1.small'=> 'Small (1 EC2 Compute Unit, 1.7 GB RAM)',
          #'m1.medium'=> 'Medium (2 EC2 Compute Unit, 3.75 GB RAM)',
          #'m1.large'=> 'Large (4 EC2 Compute Unit, 1.7 GB RAM)',
          #'m1.xlarge'=> 'Extra Large (8 EC2 Compute Unit, 15 GB RAM)',
          #'c1.medium'=> 'High-CPU Medium (5 EC2 Compute Unit, 1.7 GB RAM)',
          #'c1.xlarge'=> 'High-CPU Extra Large (20 EC2 Compute Unit, 7 GB RAM)'
      }
    end

    # -- additional Amazon methods --

    def security_groups
      @ec2.security_groups.map &:name
    end

    def ec2_instance(id)
      @ec2.instances[id]
    end

  end

end