require_relative 'shell_commands'
include ShellCommands

require_relative 'ssh_accessed_infrastructure'

module ShellBasedInfrastructure
  include SSHAccessedInfrastructure
  # -- Simulation Manager installation --

  def self.start_simulation_manager_cmd(record)
    sm_dir_name = ScalarmDirName::tmp_simulation_manager(record.sm_uuid)

    if Rails.configuration.simulation_manager_version == :go
      chain(
          cd(RemoteDir::simulation_managers),
          mute(rm(sm_dir_name, true)),
          mute("unzip #{sm_dir_name}.zip"),
          mute(cd(sm_dir_name)),
          mute('unxz scalarm_simulation_manager.xz'),
          mute('chmod a+x scalarm_simulation_manager'),
          run_in_background('./scalarm_simulation_manager', record.log_path, '&1')
      )
    elsif Rails.configuration.simulation_manager_version == :ruby
      chain(
          cd(RemoteDir::simulation_managers),
          mute('source ~/.rvm/environments/default'),
          mute(rm(sm_dir_name, true)),
          mute("unzip #{sm_dir_name}.zip"),
          mute(cd(sm_dir_name)),
          run_in_background('ruby simulation_manager.rb', record.log_path, '&1')
      )
    end
  end

  def log_exists?(record, ssh)
    path_exists = (ssh.exec_sc!("ls #{record.log_path}").exit_code == 0)
    logger.warn "Log file already exists: #{record.log_path}" if path_exists
    path_exists
  end

  def send_and_launch_sm(record, ssh)
    SSHAccessedInfrastructure.create_remote_directories(ssh)
    record.upload_file(LocalAbsolutePath::tmp_sim_zip(record.sm_uuid), RemoteDir::simulation_managers)
    output = ssh.exec!(
        Command::cd_to_simulation_managers(
            ShellBasedInfrastructure.start_simulation_manager_cmd(record)
        )
    )
    logger.debug "Simulation Manager init (stripped) output: #{output}"
    pid = ShellBasedInfrastructure.output_to_pid(output)
    record.pid = pid if pid
  end

  def self.output_to_pid(output)
    match = output.match /.*^(\d+)\s/m
    pid = match ? match[1].to_i : nil
    (pid and pid > 0) ? pid : nil
  end

  def app_running?(ssh, pid)
    not pid.blank? and (ssh.exec_sc!("ps -p #{pid}").exit_code == 0)
  end
end