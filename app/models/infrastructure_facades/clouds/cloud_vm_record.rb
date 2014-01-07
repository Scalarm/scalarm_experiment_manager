# Binds Scalarm user, experiment and cloud virtual machine instance
# providing static information about VM (set once)
#
# Attributes
# -- generic --
# cloud_type => string - name of the cloud, e.g. 'plcloud', 'amazon'
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped
# vm_id => string - instance id of the vm
# sm_uuid => string - uuid of configuration files
# initialized => boolean - whether or not SM code has been sent to this machind
# -- special for PLCloud --
# public_ip => public ip of machine which redirects to ssh port
# public_ssh_port => port of public machine redirecting to ssh private port
class CloudVmRecord < MongoActiveRecord

  def self.collection_name
    'vm_records'
  end

  def all_for_cloud(cloud_name)
    find_all_by('cloud_name', cloud_name)
  end

  # TODO: to_s method should be moved to another util class

end