module ShellBasedInfrastructure
  # -- Simulation Manager installation --

  def self.start_simulation_manager_cmd(record)
    sm_dir_name = "scalarm_simulation_manager_#{record.sm_uuid}"

    if Rails.configuration.simulation_manager_version == :go
      BashCommand.new.muted_rm(sm_dir_name, true).
          mute("unzip #{sm_dir_name}.zip").
          muted_cd(sm_dir_name).
          mute('unxz scalarm_simulation_manager.xz').
          mute('chmod a+x scalarm_simulation_manager').
          run_in_background('./scalarm_simulation_manager', record.log_path, '&1')

    elsif Rails.configuration.simulation_manager_version == :ruby
      BashCommand.new.mute('source .rvm/environments/default').
          muted_rm(sm_dir_name, true).
          mute("unzip #{sm_dir_name}.zip").
          muted_cd(sm_dir_name).
          run_in_background('ruby simulation_manager.rb', record.log_path, '&1')
    else
      BashCommand.new
    end
  end

  def log_exists?(record, ssh)
    path_exists = (ssh.exec!(BashCommand.new.run_and_get_pid("ls #{record.log_path}").to_s) == 0)
    logger.warn "Log file already exists: #{record.log_path}" if path_exists
    path_exists
  end

  def send_and_launch_sm(record, ssh)
    record.upload_file("/tmp/scalarm_simulation_manager_#{record.sm_uuid}.zip")
    output = ssh.exec!(ShellBasedInfrastructure.start_simulation_manager_cmd(record).to_s)
    output = output.split("\n").last.strip
    logger.debug "Simulation Manager init (stripped) output: #{output}"
    pid = ShellBasedInfrastructure.output_to_pid(output)
    record.pid = pid if pid
  end

  def self.output_to_pid(output)
    match = output.match /.*^(\d+)(\s)*/m
    pid = match ? match[1].to_i : nil
    (pid and pid > 0) ? pid : nil
  end

  def app_running?(ssh, pid)
    not pid.blank? and (ssh.exec_sc!("ps -p #{pid}").exit_code == 0)
  end
end