require 'infrastructure_facades/infrastructure_errors'
require 'scalarm/database/model/pl_grid_job'

# For model documentation see Scalarm::Database::Model::PlGridJob docs
class PlGridJob < Scalarm::Database::Model::PlGridJob
  include SimulationManagerRecord

  attr_join :experiment, Experiment

  def infrastructure_name
    scheduler_type
  end

  def resource_id
    self.job_identifier
  end

  def experiment
    if @attributes.include?('experiment_id')
      Experiment.find_by_id(self.experiment_id)
    else
      nil
    end
  end

  def to_s
    "JobId: #{job_identifier}, Scheduled at: #{created_at}, ExperimentId: #{experiment_id}"
  end

  def queue
    if self.queue_name.blank?
      PlGridJob.queue_for_minutes(time_limit.to_i)
    else
      self.queue_name
    end
  end

  def self.queue_for_minutes(minutes)
    if minutes < 60
      'plgrid-testing'
    elsif minutes > 60 and minutes < 72*60
      'plgrid'
    elsif minutes > 72*60
      'plgrid-long'
    else
      'plgrid'
    end
  end

  def queue_time_constraint
    walltime = time_limit.to_i

    if walltime < 60
      55
    elsif walltime >= 60 and walltime < 72*60
      72*60 - 5
    elsif walltime >= 72*60
      168*60 - 5
    end
  end

  def max_time_exceeded?
    self.created_at + self.queue_time_constraint.minutes < Time.now
  end

  def credentials
    @credentials ||= GridCredentials.find_by_user_id(user_id)
  end

  def log_file_name
    PlGridJob.log_file_name(sm_uuid)
  end

  def self.log_file_name(sm_uuid)
    SSHAccessedInfrastructure::ScalarmFileName::sim_log(sm_uuid)
  end

  def validate
    validate_credentials
  end

  def validate_credentials
    unless onsite_monitoring
      raise InfrastructureErrors::NoCredentialsError if credentials.nil?
      raise InfrastructureErrors::InvalidCredentialsError if credentials.invalid or not has_usable_credentials?
    end
  end

  def has_usable_credentials?
    credentials and credentials.login and
        (has_usable_proxy? or has_valid_password?)
  end

  def has_usable_proxy?
    credentials.secret_proxy and valid_proxy?(credentials.secret_proxy)
  end

  def has_valid_password?
    not credentials.invalid and credentials.password
  end

  def computational_resources
    "nodes=#{nodes}:ppn=#{ppn}"
  end

  # require 'grid-proxy'

  def valid_proxy?(proxy)
    true

    # TODO - use Scalarm::ServiceCore::GP::Proxy validation
    # begin
    #   GP::Proxy.new(proxy).verify!(ca_cert)
    # rescue GP::ProxyValidationError => validation_error
    #   Rails.logger.warn("Proxy validation error for PL-Grid job #{self.id}: #{validation_error.to_s}")
    #   false
    # else
    #   true
    # end
  end

end