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

    def self.long_name
      'Amazon Elastic Compute Cloud'
    end

    def all_images_info
      Hash[@ec2.images.with_owner('self').map {|i| [i.image_id, i.name] }]
    end

    def all_vm_ids
      @ec2.instances.map(&:id)
    end

    def instantiate_vms(base_name, image_id, number, params)
      Rails.logger.info "PARAMS: #{params}"

      instances = @ec2.regions['us-east-1'].instances.create(:image_id => image_id,
                                  :count => number,
                                  :instance_type => params['instance_type'],
                                  :security_groups => [ params['security_group'] ])
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

    # @return [Hash] {:host => string cloud public ip, :port => string redirected port} or nil on error
    def public_ssh_address(id)
      {host: ec2_instance(id).public_dns_name, port: '22'}
    end

    def exists?(id)
      ec2_instance(id).exists?
    end

    def instance_types
      {
          't1.micro' => 'Micro (Up to 2 EC2 Compute Units, 613 MB RAM)',
          'm1.small' => 'Small (1 EC2 Compute Unit, 1.7 GB RAM)',
          'm3.medium' => 'Medium 3rd generation (3 EC2 Compute Unit, 3.75 GB RAM)',
          #'m1.medium'=> 'Medium (2 EC2 Compute Unit, 3.75 GB RAM)',
          #'m1.large'=> 'Large (4 EC2 Compute Unit, 1.7 GB RAM)',
          #'m1.xlarge'=> 'Extra Large (8 EC2 Compute Unit, 15 GB RAM)'
          #'c1.medium'=> 'High-CPU Medium (5 EC2 Compute Unit, 1.7 GB RAM)',
          #'c1.xlarge'=> 'High-CPU Extra Large (20 EC2 Compute Unit, 7 GB RAM)'
          'c3.xlarge'=> 'High-CPU Extra Large 3rd generation (14 EC2 Compute Unit, 7.5 GB RAM)'
      }
    end

    # -- additional Amazon methods --

    def security_groups
      @ec2.security_groups.map &:name
    end

    def ec2_instance(id)
      @ec2.instances[id]
    end

    def get_subinfrastructures(user_id)
      security_groups_list = security_groups
      super(user_id).flat_map do |subinfrastructure|
        security_groups_list.flat_map do |security_group|
          subinfrastructure[:params].merge({security_group: security_group})
        end
      end
    end
  end

end