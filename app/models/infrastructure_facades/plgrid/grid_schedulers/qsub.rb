require_relative '../pl_grid_scheduler_base'

module QsubScheduler

  class PlGridScheduler < PlGridSchedulerBase
    def self.long_name
      'PL-Grid PBS'
    end

    def self.short_name
      'qsub'
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

    def prepare_job_files(sm_uuid, params)
      if params.include?(:dest_dir) and params.include?(:sm_record)
        job = params[:sm_record]

        IO.write("/tmp/#{params[:dest_dir]}/scalarm_job_#{job['sm_uuid']}.sh", prepare_job_executable)
      else
        IO.write("/tmp/scalarm_job_#{sm_uuid}.sh", prepare_job_executable)
      end
    end

    def send_job_files(sm_uuid, scp)
      paths = ["/tmp/scalarm_simulation_manager_#{sm_uuid}.zip",
               "/tmp/scalarm_job_#{sm_uuid}.sh"
      ]
      scp.upload_multiple! paths, '.'
    end

    def submit_job(ssh, sm_record)
      # logger.debug("QSUB cmd: #{qsub_cmd.join(' ')}")
      submit_job_output = ssh.exec!(submit_job_cmd(sm_record))
      logger.debug("Output lines: #{submit_job_output}")

      if submit_job_output != nil
        output_lines = submit_job_output.split("\n")

        output_lines.each do |line|
          # checking if the first element is integer -> it is the identifier we are looking for
          if line[0].to_i.to_s == line[0]
            sm_record.job_id = line.strip
            return true
          end
        end
      end

      false
    end

    def submit_job_cmd(sm_record)
      #  schedule the job with qsub
      qsub_cmd = [
          'qsub',
          '-q', sm_record.queue,
          "#{sm_record.grant_id.blank? ? '' : "-A #{sm_record.grant_id}"}",
          "#{sm_record.nodes.blank? ? '' : "-l nodes=#{sm_record.nodes}:ppn=#{sm_record.ppn}"}",
          '-j oe', # mix stderr with stdout
          '-o', sm_record.log_path, # output log
          '-l', "walltime=#{sm_record.time_limit.to_i.minutes.to_i}" # convert minutes to seconds
      ]

      [ "chmod a+x scalarm_job_#{sm_record.sm_uuid}.sh",
        "echo \"sh scalarm_job_#{sm_record.sm_uuid}.sh #{sm_record.sm_uuid}\" | #{qsub_cmd.join(' ')}" ].join(';')
    end

    def pbs_state(ssh, job)
      state_output = ssh.exec!("qstat #{job.job_id}")
      state_output.split("\n").each do |line|
        if line.start_with?(job.job_id.split('.').first)
          info = line.split(' ')
          return info[4]

        elsif line.start_with?('qstat: Unknown Job Id')
          return 'U'
        end
      end
      # unknown
      'U'
    end

    # States from man qstat:
    # C -  Job is completed after having run/
    # E -  Job is exiting after having run.
    # H -  Job is held.
    # Q -  job is queued, eligible to run or routed.
    # R -  job is running.
    # T -  job is being moved to new location.
    # W -  job is waiting for its execution time
    # (-a option) to be reached.
    # S -  (Unicos only) job is suspend.

    STATES_MAPPING = {
        'C'=>:deactivated,
        'E'=>:deactivated,
        'H'=>:running,
        'Q'=>:initializing,
        'R'=>:running,
        'T'=>:running,
        'W'=>:initializing,
        'S'=>:error,
        'U'=>:deactivated # probably it's not in queue
    }

    def status(ssh, job)
      STATES_MAPPING[pbs_state(ssh, job)] or :error
    end

    def cancel(ssh, job)
      ssh.exec!(cancel_sm_cmd(job))
    end

    def get_log(ssh, job)
      ssh.exec! get_log_cmd(job)
    end

    def get_log_cmd(sm_record)
      if sm_record.log_path.blank?
        ""
      else
        "tail -25 #{sm_record.log_path}; rm #{sm_record.log_path}"
      end
    end

    def cancel_sm_cmd(sm_record)
      if sm_record.job_id.blank?
        ""
      else
        "qdel #{sm_record.job_id}"
      end
    end

  end

end