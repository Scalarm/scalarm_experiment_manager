# Binds Scalarm user, experiment and cloud virtual machine instance
# providing static information about VM (set once)
#
# Attributes
# -- generic --
# cloud_name => string - name of the cloud, e.g. 'pl_cloud', 'amazon'
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# image_secrets_id => id of CloudImageSecrets
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped - in minutes
# vm_id => string - instance id of the vm
# sm_uuid => string - uuid of configuration files
# sm_initialized => boolean - whether or not SM code has been sent to this machind
# vm_init_count => integer - how many times VM was initialized/reinitialized
#
# public_host => public hostname of machine which redirects to ssh port
# public_ssh_port => port of public machine redirecting to ssh private port
class CloudVmRecord < MongoActiveRecord
  include SimulationManagerRecord

  SSH_AUTH_METHODS = %w(password)

  def resource_id
    self.vm_id
  end

  def self.collection_name
    'vm_records'
  end

  #  upload file to the VM - use only password authentication
  def upload_file(local_path, remote_path='.')
    Net::SCP.start(public_host, image_secrets.image_login, ssh_params) do |scp|
      scp.upload! local_path, remote_path
    end
  end

  def ssh_session
    Net::SSH.start(public_host, image_secrets.image_login, ssh_params)
  end

  def ssh_start
    Net::SSH.start(public_host, image_secrets.image_login, ssh_params) do |ssh|
      yield ssh
    end
  end

  def image_secrets
    @image_secrets ||= CloudImageSecrets.find_by_id(image_secrets_id)
  end

  def experiment
    @experiment ||= Experiment.find_by_id(experiment_id)
  end

  # additional info for specific cloud should be provided by CloudClient
  def to_s
    "Id: #{vm_id}, Launched at: #{created_at}, Time limit: #{time_limit}, "
    "SSH address: #{public_host}:#{public_ssh_port}"
  end

  def ssh_params
    {
        port: public_ssh_port, password: image_secrets.secret_image_password,
        auth_methods: SSH_AUTH_METHODS, paranoid: false, user_known_hosts_file: %w(/dev/null),
        timeout: 30
    }
  end

  def update_ssh_address!(vm_instance)
    if not self.public_host or not self.public_ssh_port
      psa = vm_instance.public_ssh_address
      self.public_host, self.public_ssh_port = psa[:host], psa[:port]
      self.save
    end
  end

  def log_path
    "/tmp/log_sm_#{sm_uuid}"
  end

end