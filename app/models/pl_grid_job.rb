# Attributes
# user_id => integer - the user who scheduled this job - mongoid in the future
# created_at => time - when this job were scheduled
# time_limit => time - when this job should be stopped
# job_id => string - glite id of the job

class PlGridJob < MongoActiveRecord

  def self.collection_name
    'grid_jobs'
  end



end