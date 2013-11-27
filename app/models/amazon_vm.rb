# Attributes
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped
# vm_id => string - instance id of the vm
# instance_type => string - typu of the vm
# sm_uuid => string - uuid of configuration files
# initialized => boolean - whether or not SM code has been sent to this machind

class AmazonVm < MongoActiveRecord

  def self.collection_name
    'amazon_vms'
  end

  def to_s
    "Id: #{vm_id}, Type: #{instance_type}, Launch at: #{created_at}, Time limit: #{time_limit}"
  end

  def self.amazon_instance_types
    [
        ['Micro (Up to 2 EC2 Compute Units, 613 MB RAM)', 't1.micro'],
    #['Small (1 EC2 Compute Unit, 1.7 GB RAM)', "m1.small"],
    #['Medium (2 EC2 Compute Unit, 3.75 GB RAM)', "m1.medium"],
    # ["Large (4 EC2 Compute Unit, 1.7 GB RAM)", "m1.large"],
    # ["Extra Large (8 EC2 Compute Unit, 15 GB RAM)", "m1.xlarge"],
    #['High-CPU Medium (5 EC2 Compute Unit, 1.7 GB RAM)', "c1.medium"],
    #['High-CPU Extra Large (20 EC2 Compute Unit, 7 GB RAM)', "c1.xlarge"]
    ]
  end

end