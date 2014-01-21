# Binds Scalarm user, experiment and cloud virtual machine instance
# providing static information about VM (set once)
#
# Attributes
# -- generic --
# cloud_name => string - name of the cloud, e.g. 'pl_cloud', 'amazon'
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# image_id => id of image in Cloud
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped
# vm_id => string - instance id of the vm
# sm_uuid => string - uuid of configuration files
# sm_initialized => boolean - whether or not SM code has been sent to this machind
# vm_init_count => integer - how many times VM was initialized/reinitialized
#
# public_host => public hostname of machine which redirects to ssh port
# public_ssh_port => port of public machine redirecting to ssh private port
class CloudVmRecord < MongoActiveRecord

  SSH_AUTH_METHODS = %w(password)

  def self.collection_name
    'vm_records'
  end

  def initialize(attributes)
    super(attributes)

    @image_cache = nil
  end

  def time_limit_exceeded?
    created_at + time_limit.to_i.minutes < Time.now
  end

  #  upload file to the VM - use only password authentication
  def upload_file(local_path, remote_path='.')
    Net::SCP.start(public_host, image_instance.image_login,
              port: public_ssh_port, password: image_instance.secret_image_password,
              auth_methods: SSH_AUTH_METHODS) do |scp|
      scp.upload! local_path, remote_path
    end
  end

  def ssh_session
    Net::SSH.start(public_host, image_instance.image_login,
              port: public_ssh_port, password: image_instance.secret_image_password,
              auth_methods: SSH_AUTH_METHODS) do |ssh|
      yield ssh
    end
  end

  # TODO: is this can be used?
  def image_instance
    @image_cache = CloudImageSecrets.find_by_image_id(image_id.to_s) if not @image_cache
    @image_cache
  end

  def update_ssh_address(vm_instance)
    public_ssh_address = vm_instance.public_ssh_address

    self.public_host = public_ssh_address[:ip]
    self.public_ssh_port = public_ssh_address[:port]

    self.save
  end

  # additional info for specific cloud should be provided by CloudClient
  def to_s
    "Id: #{vm_id}, Launched at: #{created_at}, Time limit: #{time_limit}, "
    "SSH address: #{public_host}:#{public_ssh_port}"
  end

end