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

end