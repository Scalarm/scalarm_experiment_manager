# Attributes (besides of generic SimulationManagerRecord's)
# - credentials_id => id of PrivateMachineCredentials
# - pid => PID of SimulationManager process executed at remote machine

class PrivateMachineRecord < MongoActiveRecord
  extend Forwardable
  include SimulationManagerRecord

  # delegate session methods just for convenience
  def_delegators :@credentials, :upload_file, :ssh_session, :scp_session

  attr_join :credentials, PrivateMachineCredentials

  def self.collection_name
    'private_machine_records'
  end

  def self.ids_auto_convert
    false
  end

  def resource_id
    task_desc
  end

  def task_desc
    "#{credentials.nil? ? '[credentials missing!]' : credentials.machine_desc} (#{pid.nil? ? 'init' : pid})"
  end

  def credentials
    @credentials ||= PrivateMachineCredentials.find_by_id(credentials_id)
  end

  def experiment
    @experiment ||= Experiment.find_by_id(experiment_id)
  end

  def log_path
    "/tmp/log_sm_#{sm_uuid}"
  end

  def monitoring_group
    self.credentials_id
  end

  def validate
    raise InfrastructureErrors::NoCredentialsError if credentials_id.nil?
    raise InfrastructureErrors::InvalidCredentialsError if credentials.invalid
  end

  def computational_resources
    "ppn=#{ppn}"
  end

end