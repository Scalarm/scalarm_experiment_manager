require_relative 'shell_commands'

require_relative 'ssh_accessed_infrastructure'

module ShellBasedInfrastructure
  include SSHAccessedInfrastructure
  # -- Simulation Manager installation --

   # Starts SimulationManager app assuming the ZIP with SiM is in current directory
  def self.start_simulation_manager_cmd(record)
    sm_dir_name = ScalarmDirName::tmp_simulation_manager(record.sm_uuid)

    log_path = record.absolute_log_path

    if Rails.configuration.simulation_manager_version == :go
      BashCommand.new.rm(sm_dir_name, true).log_last_command(log_path).
          log("unzip #{sm_dir_name}.zip", log_path).
          cd(sm_dir_name).log_last_command.
          log('unxz scalarm_simulation_manager.xz', log_path).
          log('chmod a+x scalarm_simulation_manager', log_path).
          run_in_background('./scalarm_simulation_manager', log_path).to_s
    elsif Rails.configuration.simulation_manager_version == :ruby
      BashCommand.new.log('source ~/.rvm/environments/default', log_path).
          rm(sm_dir_name, true).log_last_command(log_path).
          log("unzip #{sm_dir_name}.zip", log_path).
          cd(sm_dir_name).log_last_command.
          run_in_background('ruby simulation_manager.rb', log_path).to_s
    end
  end

  def log_exists?(record, ssh)
    absolute_log_path = record.absolute_log_path
    path_exists = (ssh.exec_sc!("ls #{absolute_log_path}").exit_code == 0)
    logger.warn "Log file already exists: #{absolute_log_path}" if path_exists
    path_exists
  end

  def send_and_launch_sm(record, ssh)
    SSHAccessedInfrastructure.create_remote_directories(ssh)
    logger.debug("Uploading SiM to #{record.host}")
    record.upload_file(LocalAbsolutePath::tmp_sim_zip(record.sm_uuid), RemoteDir::scalarm_root)
    start_command = ShellBasedInfrastructure.start_simulation_manager_cmd(record)
    logger.debug("Starting SiM with #{start_command} in remote SiM dir")
    output = ssh.exec!(
        Command::cd_to_simulation_managers(
            start_command
        )
    )
    output = ShellBasedInfrastructure.strip_pid_output(output)
    logger.debug "Simulation Manager init (stripped) output: #{output}"
    pid = ShellBasedInfrastructure.output_to_pid(output)
    record.pid = pid if pid
  end

  def self.strip_pid_output(output)
    output.split("\n").last.strip
  end

  def self.output_to_pid(output)
    match = output.match /.*^(\d+)\s*/m
    pid = match ? match[1].to_i : nil
    (pid and pid > 0) ? pid : nil
  end

  def app_running?(ssh, pid)
    not pid.blank? and (ssh.exec_sc!("ps -p #{pid}").exit_code == 0)
  end
end