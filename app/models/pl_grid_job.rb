# Attributes
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped - in minutes
# job_id => string - glite id of the job
# sm_uuid => string - uuid of configuration files
# scheduler_type => string - short name of scheduler, eg. pbs

class PlGridJob < MongoActiveRecord

  def self.collection_name
    'grid_jobs'
  end

  # time to wait to job initialization - after that, job will be resubmitted [minutes object]
  def max_init_time
    self.time_limit.to_i.hours > 72 ? 40.minutes : 20.minutes
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

end