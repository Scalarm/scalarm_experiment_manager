# Attributes (besides of generic SimulationManagerRecord's)
# - credentials_id => id of PrivateMachineCredentials
# - pid => PID of SimulationManager process executed at remote machine

require 'scalarm/database/model/private_machine_record'

class PrivateMachineRecord < Scalarm::Database::Model::PrivateMachineRecord
  extend Forwardable
  include SimulationManagerRecord

  attr_join :credentials, PrivateMachineCredentials
  attr_join :experiment, Experiment

  # delegate session methods just for convenience
  def_delegators :credentials, :upload_file, :ssh_session, :scp_session

  def infrastructure_name
    'private_machine'
  end

  def resource_id
    task_desc
  end

  def task_desc
    "#{credentials.nil? ? '[credentials missing!]' : credentials.machine_desc} (#{pid.nil? ? 'init' : pid})"
  end

  def log_path
    SSHAccessedInfrastructure::RemoteAbsolutePath::sim_log(sm_uuid)
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