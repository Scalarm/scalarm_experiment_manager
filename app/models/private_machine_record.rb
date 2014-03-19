# Attributes
# -- generic --
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# private_machine_id => id of PrivateMachineCredentials
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped - in minutes
# pid => PID of SimulationManager process executed at remote machine
# sm_uuid => string - uuid of configuration files
# sm_initialized => boolean - whether or not SM code has been sent to this machind

class PrivateMachineRecord < MongoActiveRecord

  SSH_AUTH_METHODS = %w(password)

  # time to wait to VM initialization - after that, VM will be reinitialized [minutes object]
  def max_init_time
    self.time_limit.to_i.minutes > 72.hours ? 40.minutes : 20.minutes
  end

  def self.collection_name
    'private_machine_records'
  end

  def task_desc
    "#{credentials.machine_desc} (#{pid? ? pid : 'init'})"
  end

  def initialize(attributes)
    super(attributes)
  end

  #  upload file to the VM - use only password authentication
  def upload_file(local_path, remote_path='.')
    Net::SCP.start(credentials.host, credentials.login,
                   port: credentials.ssh_port, password: credentials.secret_password,
                   auth_methods: SSH_AUTH_METHODS) do |scp|
      scp.upload! local_path, remote_path
    end
  end

  def ssh_session
    Net::SSH.start(credentials.host, credentials.login,
              port: credentials.ssh_port, password: credentials.secret_password,
              auth_methods: SSH_AUTH_METHODS) do |ssh|
      yield ssh
    end
  end

  def credentials
    @credentials ||= PrivateMachineCredentials.find_by_id(private_machine_id)
  end

  def experiment
    @experiment ||= Experiment.find_by_id(experiment_id)
  end

  # additional info for specific cloud should be provided by CloudClient
  def to_s
    "Id: #{task_desc}, Launched at: #{created_at}, Time limit: #{time_limit}, "
    "SSH address: #{credentials.host}:#{credentials.ssh_port}"
  end

end