# Attributes (besides of generic SimulationManagerRecord's)
# - credentials_id => id of PrivateMachineCredentials
# - pid => PID of SimulationManager process executed at remote machine

class PrivateMachineRecord < MongoActiveRecord
  include SimulationManagerRecord

  def self.collection_name
    'private_machine_records'
  end

  def resource_id
    task_desc
  end

  def task_desc
    "#{credentials.nil? ? '[credentials missing!]' : credentials.machine_desc} (#{pid.nil? ? 'init' : pid})"
  end

  def upload_file(*args)
    credentials.upload_file(*args)
  end

  def ssh_session(*args)
    credentials.ssh_session(*args)
  end

  def ssh_start(*args, &block)
    credentials.ssh_start(*args, &block)
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

end