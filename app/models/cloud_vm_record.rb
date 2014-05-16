# Binds Scalarm user, experiment and cloud virtual machine instance
# providing static information about VM (set once)
#
# Attributes (besides of generic SimulationManagerRecord's)
# - cloud_name => string - name of the cloud, e.g. 'pl_cloud', 'amazon'
# - image_secrets_id => id of CloudImageSecrets
# - vm_id => string - instance id of the vm
# - pid => integer - PID of SimulationManager application (if executed)
#
# - public_host => public hostname of machine which redirects to ssh port
# - public_ssh_port => port of public machine redirecting to ssh private port
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

  def has_ssh_address?
    (not self.public_host.blank?) and (not self.public_ssh_port.blank?)
  end

  def update_ssh_address!(vm_instance)
    psa = vm_instance.public_ssh_address
    self.public_host, self.public_ssh_port = psa[:host], psa[:port]
    self.save
  end

  def log_path
    "/tmp/log_sm_#{sm_uuid}"
  end

  def monitoring_group
    self.image_secrets_id
  end

end