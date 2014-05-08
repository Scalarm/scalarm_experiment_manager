# Attributes
# -- generic --
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# credentials_id => id of PrivateMachineCredentials
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped - in minutes
# pid => PID of SimulationManager process executed at remote machine
# sm_uuid => string - uuid of configuration files
# sm_initialized => boolean - whether or not SM code has been sent to this machind

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