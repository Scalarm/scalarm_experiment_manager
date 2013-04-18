# Attributes
# user_id => integer - the user who scheduled this job - mongoid in the future
# experiment_id => the experiment which should be computed by this job
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped
# job_id => string - glite id of the job
# sm_uuid => string - uuid of configuration files

class PlGridJob < MongoActiveRecord

  def self.collection_name
    'grid_jobs'
  end

  def experiment
    if @attributes.include?('experiment_id')
      DataFarmingExperiment.find_by_experiment_id(self.experiment_id.to_i)
    else
      nil
    end
  end

end