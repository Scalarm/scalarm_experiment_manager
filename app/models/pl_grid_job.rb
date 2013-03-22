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

  def current_state(ssh)
    state_output = ssh.exec!("glite-wms-job-status #{self.job_id}")
    current_state_line = state_output.split("\n").select{|line| line.start_with?('Current Status:')}.first

    current_state_line['Current Status:'.length..-1].strip
  end

  def is_done(ssh)
    not %w(Ready Scheduled Running).include?(current_state(ssh))
  end

  def cancel(ssh)
    ssh.open_channel do |channel|
      channel.send_data("glite_wms_job-cancel #{self.job_id}")
      channel.send_data('y')
      channel.close
    end
  end

  def submit(ssh)
    #  schedule the job with glite wms
    submit_job_output = ssh.exec!("glite-wms-job-submit -a scalarm_job_#{self.sm_uuid}.jdl")
    Rails.logger.debug("Output lines: #{submit_job_output}")

    if submit_job_output != nil
      output_lines = submit_job_output.split("\n")

      output_lines.each_with_index do |line, index|
        if line.include?('Your job identifier is:')
          if output_lines[index + 1].start_with?('http')
            self.job_id = output_lines[index + 1]
            return true
          elsif output_lines[index + 2].start_with?('http')
            self.job_id = output_lines[index + 2]
            return true
          end
        end
      end
    end

    false
  end

  def restart(ssh)
    cancel(ssh)
    if submit(ssh)
      save
      true
    else
      false
    end
  end

end