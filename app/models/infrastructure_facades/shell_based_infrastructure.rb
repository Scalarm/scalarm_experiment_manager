module ShellBasedInfrastructure
  # -- Simulation Manager installation --

  def start_simulation_manager_cmd(record)
    sm_dir_name = "scalarm_simulation_manager_#{record.sm_uuid}"
    chain(
        mute('source .rvm/environments/default'),
        mute(rm(sm_dir_name, true)),
        mute("unzip #{sm_dir_name}.zip"),
        mute(cd(sm_dir_name)),
        run_in_background('ruby simulation_manager.rb', record.log_path, '&1')
    )
  end

  def log_exists?(record, ssh)
    path_exists = (ssh.exec!(run_and_get_pid "ls #{record.log_path}") == 0)
    log.warn "Log file already exists: #{record.log_path}" if path_exists
    path_exists
  end

  def send_and_launch_sm(record, ssh)
    record.upload_file("/tmp/scalarm_simulation_manager_#{record.sm_uuid}.zip")
    output = ssh.exec!(start_simulation_manager_cmd(record))
    logger.debug "Simulation Manager PID: #{output}"
    output.split("\n").each do |line|
      if (record.pid = line.to_i) > 0
        return record.pid
      end
    end
    false
  end
end