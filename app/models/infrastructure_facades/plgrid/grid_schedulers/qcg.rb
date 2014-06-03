require_relative '../pl_grid_scheduler_base'

module QcgScheduler

  class PlGridScheduler < PlGridSchedulerBase
    JOBID_RE = /.*jobId\s+=\s+(.+)$/
    STATE_RE = /.*Status:\s+(\w+).*/
    STATUS_DESC_RE = /.*StatusDescription:\s+(.*)\n/

    def self.long_name
      'QosCosGrid'
    end

    def self.short_name
      'qcg'
    end

    def long_name
      self.class.long_name
    end

    def short_name
      self.class.short_name
    end

    def prepare_job_files(sm_uuid)
      IO.write("/tmp/scalarm_job_#{sm_uuid}.sh", prepare_job_executable)
      IO.write("/tmp/scalarm_job_#{sm_uuid}.qcg", prepare_job_descriptor(sm_uuid))
    end

    # TODO: add host #QCG host=zeus.cyfronet.pl
    # - reef.man.poznan.pl
    # - inula.man.poznan.pl
    # - moss.man.poznan.pl
    # - nova.wcss.wroc.pl
    # - zeus.cyfronet.pl
    # - galera.task.gda.pl
    # - hydra.icm.edu.pl
    # TODO: test in UI to write stout+err to one file
    # TODO: add grant #QCG grant=plgpiontek_grant
    # TODO: add ruby module #QCG module=nwchem/6.0
    # TODO: cores/nodes #QCG nodes=12:12 (nodes:cores[:processes])
    # TODO: #QCG procs=32 - use for MPI
    # TODO: queue #QCG queue=plgrid
    # TODO: walltime #QCG walltime=P3DT12H
    def prepare_job_descriptor(uuid)
      log_path = PlGridJob.log_path(uuid)
      <<-eos
#QCG executable=scalarm_job_#{uuid}.sh
#QCG argument=#{uuid}
#QCG output=#{log_path}.out
#QCG error=#{log_path}.err
#QCG stage-in-file=scalarm_job_#{uuid}.sh
#QCG stage-in-file=scalarm_simulation_manager_#{uuid}.zip
      eos
    end

    def send_job_files(sm_uuid, scp)
      scp.upload! "/tmp/scalarm_simulation_manager_#{sm_uuid}.zip", '.'
      scp.upload! "/tmp/scalarm_job_#{sm_uuid}.sh", '.'
      scp.upload! "/tmp/scalarm_job_#{sm_uuid}.qcg", '.'
    end

    def submit_job(ssh, job)
      ssh.exec!("chmod a+x scalarm_job_#{job.sm_uuid}.sh")
      submit_job_output = ssh.exec!("qcg-sub scalarm_job_#{job.sm_uuid}.qcg")

      Rails.logger.debug("QCG output lines: #{submit_job_output}")

      submit_job_output and (job.job_id = QcgScheduler::PlGridScheduler.parse_job_id(submit_job_output))
    end

    def self.parse_job_id(submit_job_output)
      jobid_match = submit_job_output.match(JOBID_RE)
      jobid_match and jobid_match[1] or nil
    end

    # TODO: translate comments
    # Job states (Polish, from QCG documentation):
    # UNSUBMITTED – przetwarzanie zadania wstrzymane z powodu zależności kolejnościowych,
    # UNCOMMITED - zadanie oczekuje na zatwierdzenie do przetwarzania,
    # QUEUED – zadanie oczekuje w kolejce na przetwarzanie,
    # PREPROCESSING – system przygotowuje środowisko uruchomieniowe dla zadania,
    # PENDING – aplikacja w ramach danego zadania oczekuje na wykonanie w systemie kolejkowym,
    # RUNNING – aplikacja użytkownika jest wykonywana w ramach zadania,
    # STOPPED – aplikacja została zakończona, system nie rozpoczął jeszcze czynności związanych z kopiowaniem wyników i czyszczeniem środowiska wykonawczego,
    # POSTPROCESSING – system wykonuje akcje mające na calu zakończenie zadania: kopiuje pliki/katalogi wynikowe, czyści środowisko wykonawcze, etc.,
    # FINISHED – zadanie zostało zakończone,
    # FAILED – błąd przetwarzania zadania,
    # CANCELED – zadanie anulowane przez użytkownika.

    # Job states (Polish, from QCG documentation):
    # UNSUBMITTED – task processing suspended because of queue dependencies
    # UNCOMMITED - task is waiting for processing confirmation
    # QUEUED – task is waiting in queue for processing
    # PREPROCESSING – system is preparing environment for task
    # PENDING – aplikacja w ramach danego zadania oczekuje na wykonanie w systemie kolejkowym,
    # RUNNING – aplikacja użytkownika jest wykonywana w ramach zadania,
    # STOPPED – aplikacja została zakończona, system nie rozpoczął jeszcze czynności związanych z kopiowaniem wyników i czyszczeniem środowiska wykonawczego,
    # POSTPROCESSING – system wykonuje akcje mające na calu zakończenie zadania: kopiuje pliki/katalogi wynikowe, czyści środowisko wykonawcze, etc.,
    # FINISHED – zadanie zostało zakończone,
    # FAILED – błąd przetwarzania zadania,
    # CANCELED – zadanie anulowane przez użytkownika.

    STATES_MAPPING = {
        'UNSUBMITTED' => :initializing,
        'UNCOMMITED' => :initializing,
        'QUEUED' => :initializing,
        'PREPROCESSING' => :initializing,
        'PENDING' => :initializing,
        'RUNNING' => :running,
        'STOPPED' => :deactivated, # TODO: :running? it's probably not ready for fetching logs
        'POSTPROCESSING' => :deactivated,
        'FINISHED' => :deactivated,
        'FAILED' => :deactivated,
        'CANCELED' => :deactivated,
        'UNKNOWN' => :error
    }

    def status(ssh, job)
      STATES_MAPPING[qcg_state(ssh, job.job_id)] or :error
    end

    def qcg_state(ssh, job_id)
      QcgScheduler::PlGridScheduler.parse_qcg_state(get_job_info(ssh,job_id))
    end

    def qcg_status_desc(ssh, job_id)
      QcgScheduler::PlGridScheduler.parse_qcg_status_desc(get_job_info(ssh,job_id))
    end

    def self.parse_qcg_state(state_output)
      state_match = state_output.match(STATE_RE)
      if state_match
        state_match[1]
      else
        'UNKNOWN'
      end
    end

    def self.parse_qcg_status_desc(output)
      state_match = output.match(STATUS_DESC_RE)
      if state_match
        state_match[1]
      else
        nil
      end
    end

    def get_job_info(ssh, job_id)
      ssh.exec!("qcg-info #{job_id}")
    end

    def cancel(ssh, job)
      output = ssh.exec!("qcg-cancel #{job.job_id}")
      Rails.logger.debug("QCG cancel output:\n#{output}")
      output
    end

    def get_log(ssh, job)
      err_log = ssh.exec! "tail -25 #{job.log_path}.err"
      out_log = ssh.exec! "tail -25 #{job.log_path}.out"
      ssh.exec! "rm #{job.log_path}.err"
      ssh.exec! "rm #{job.log_path}.out"

      if qcg_state(ssh, job.job_id) == 'FAILED'
        <<-eos
--- QCG Status description ---
#{qcg_status_desc(ssh, job.job_id)}
--- STDOUT ---
#{out_log}
--- STDERR ---
#{err_log}
        eos
      else
        <<-eos
--- STDOUT ---
#{out_log}
--- STDERR ---
#{err_log}
        eos
      end
    end

    def clean_after_job(ssh, job)
      super
      ssh.exec!("rm scalarm_job_#{job.sm_uuid}.qcg")
    end

  end

end