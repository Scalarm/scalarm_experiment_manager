# Attributes
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped - in minutes
# job_id => string - queue system specific id of the job
# sm_uuid => string - uuid of configuration files
# scheduler_type => string - short name of scheduler, eg. pbs

class PlGridJob < MongoActiveRecord
  include SimulationManagerRecord

  def self.collection_name
    'grid_jobs'
  end

  def resource_id
    self.job_id
  end

  def experiment
    if @attributes.include?('experiment_id')
      Experiment.find_by_id(self.experiment_id)
    else
      nil
    end
  end

  def to_s
    "JobId: #{job_id}, Scheduled at: #{created_at}, ExperimentId: #{experiment_id}"
  end

  def queue
    walltime = time_limit.to_i

    if walltime < 60
      'plgrid-testing'
    elsif walltime > 60 and walltime < 72*60
      'plgrid'
    elsif walltime > 72*60
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

  def log_path
    PlGridJob.log_path(sm_uuid)
  end

  def self.log_path(uuid)
    "#{uuid}.log"
  end

end