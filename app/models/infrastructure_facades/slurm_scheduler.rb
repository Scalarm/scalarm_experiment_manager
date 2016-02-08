require 'infrastructure_facades/plgrid/pl_grid_scheduler_base.rb'

# Implements commands required to submit, monitor and cancel jobs using
# the SLURM scheduling system
class SlurmScheduler < PlGridSchedulerBase

  def initialize
    super(InfrastructureTaskLogger.new(self.short_name))
  end

  def self.long_name
    'SLURM'
  end

  def self.short_name
    'slurm'
  end

  def long_name
    self.class.long_name
  end

  def short_name
    self.class.short_name
  end

  def onsite_monitorable?
    true
  end

  def submit_job(ssh, sm_record)
    submit_job_cmd = Command::cd_to_simulation_managers(submit_job_cmd(sm_record)).to_s
    submit_job_output = ssh.exec!(submit_job_cmd)
    logger.debug("SLURM cmd: #{submit_job_cmd}, output lines:\n#{submit_job_output}")

    m = submit_job_output.match(/Submitted batch job .*/)
    raise(JobSubmissionFailed.new(submit_job_output)) unless m

    m[0].split.last
  end

  def status(ssh, job_record)
    scontrol_output = ssh.exec!(BashCommand.new.append("scontrol show job #{job_record.job_identifier}").to_s)
    logger.debug("SLURM scontrol output #{scontrol_output}")
    state_line = scontrol_output.match(/JobState=.*\s/)

    if state_line
      job_state_line = state_line[0]
      state = job_state_line.split('JobState=').last.split.first

      logger.debug("SLURM state based on JobState #{state} --- #{JOB_STATE_MAPPING[state.gsub(/\+/, '')]}")

      return JOB_STATE_MAPPING[state.gsub(/\+/, '')]
    end

    sacct_output = ssh.exec!(BashCommand.new.append("sacct -j #{job_record.job_identifier}").to_s)
    logger.debug("SLURM sacct_output #{sacct_output}")

    job_id_idx = nil; state_idx = nil

    sacct_output.split("\n").each do |line|
      logger.debug("SLURM: line: #{line}")
      if job_id_idx.nil?
        job_id_idx = line.split.index("JobID")
        state_idx = line.split.index("State")
      else
        job_id = line.split[job_id_idx]
        state = line.split[state_idx]

        if job_id == job_record.job_identifier
          Rails.logger.debug { "Returning #{JOB_STATE_MAPPING[state.gsub(/\+/, '')]}" }
          return JOB_STATE_MAPPING[state.gsub(/\+/, '')]
        end
      end
    end

    Rails.logger.error("Couldn't find job state - #{sacct_output}")
    # :error
    raise StandardError("Couldn't find job state")
  end

  JOB_STATE_MAPPING = {
    'PENDING' => :initializing,
    'CONFIGURING' => :initializing,
    'RUNNING' => :running,
    'COMPLETING' => :deactivated,
    'COMPLETED' => :deactivated,
    'CANCELLED' => :deactivated,
    'FAILED' => :error,
    'NODE_FAIL' => :error,
    'PREEMPTED' => :error,
    'SUSPENDED' => :error,
    'TIMEOUT' => :error,
  }


  def prepare_job_files(sm_uuid, params)
    execution_dir = if params.include?(:dest_dir)
                      params[:dest_dir]
                    else
                      LocalAbsoluteDir::tmp
                    end

    params = params[:sm_record] if params.include?(:sm_record)

    IO.write("#{execution_dir}/#{job_script_file(sm_uuid)}", prepare_job_executable)
    IO.write("#{execution_dir}/#{job_description_file(sm_uuid)}", prepare_job_descriptor(sm_uuid, params))
  end

  def tmp_job_files_list(sm_uuid)
    [
        job_script_file(sm_uuid),
        job_description_file(sm_uuid)
    ].collect {|name| File.join(LocalAbsoluteDir::tmp, name)}
  end


  def prepare_job_descriptor(uuid, params)
    log_path = ScalarmFileName::sim_log(uuid)
    <<-eos
#!/bin/bash -l
#{params['nodes'].blank? ? '' : "#SBATCH -N #{params['nodes']}" }
#{params['ppn'].blank? ? '' : "#SBATCH --ntasks-per-node=#{params['nodes']}" }
#{params['grant_identifier'].blank? ? '' : "#SBATCH -A #{params['grant_identifier']}" }
#{params['time_limit'].blank? ? '' : "#SBATCH --time=#{params['time_limit']}" }
#{params['queue_name'].blank? ? '' : "#SBATCH -p #{params['queue_name']}" }
#{params['memory'].blank? ? '' : "#SBATCH --mem=#{params['memory']}" }
#SBATCH --output="#{log_path}"
#SBATCH --error="#{log_path}"

cd $SLURM_SUBMIT_DIR
./#{job_script_file(uuid)} #{uuid} # SiM unpacking and execution script
    eos
  end


  def cancel(ssh, job)
    cmd = cancel_sm_cmd(job).to_s
    output = ssh.exec!(cmd)
    logger.debug("SLURM cmd: #{cmd}, output lines:\n#{output}")
  end

  def get_log(ssh, job)
    ssh.exec!(get_log_cmd(job).to_s)
  end

  def get_log_cmd(sm_record)
    log_path = sm_record.absolute_log_path

    BashCommand.new.append(
      if log_path.blank?
        'echo no log_path specified'
      else
        # A patch to resolve SCAL-954
        # try invoking tail of log file 10 times with 1 second sleep interval; always try to remove log file
        # the command will return 0
        "export NAMEF=#{log_path}; export ITER=0; export EC=1; while [ $ITER -lt 30 -a $EC -ne 0 ]; do tail -80 $NAMEF; EC=$?; ITER=`expr $ITER + 1`; [ $EC -ne 0 ] && sleep 1; done; rm -f #{log_path}"
      end
    )
  end

  def cancel_sm_cmd(sm_record)
    BashCommand.new.append(
      if sm_record.job_identifier.blank?
        'echo no job_identifier specified'
      else
        "scancel #{sm_record.job_identifier} || true"
      end
    )
  end

  def clean_after_sm_cmd(sm_record)
    BashCommand.new.append(super).rm(File.join(RemoteDir::scalarm_root, job_description_file(sm_record.sm_uuid)), true)
  end

  ##
  # Returns list of hashes representing distinct resource configurations
  # Resource configurations are distinguished by:
  #  * grant ids
  # @param user_id [BSON::ObjectId, String]
  # @return [Array<Hash>] list of resource configurations
  def get_resource_configurations(user_id)
    []
  end


  # Assumption: working dir contains job files
  def submit_job_cmd(sm_record)
    sm_uuid = sm_record.sm_uuid

    BashCommand.new.
        append("chmod a+x #{job_script_file(sm_uuid)}").
        append("sbatch #{job_description_file(sm_uuid)}")
  end

  def job_description_file(sm_uuid)
    "scalarm_slurm_job_#{sm_uuid}.sh"
  end
end
