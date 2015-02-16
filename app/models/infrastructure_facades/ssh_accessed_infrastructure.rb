module SSHAccessedInfrastructure
  extend ShellCommands

  def initialize(*args)
    super(*args)
  end

  def self.create_remote_directories(ssh)
    [RemoteDir::scalarm_root, RemoteDir::simulation_managers, RemoteDir::monitoring].each do |name|
      ssh.exec!(mkdir(name))
    end
  end

  module LocalAbsolutePath
    def self.tmp_monitoring_config(sm_uuid)
      File.join(LocalAbsoluteDir::tmp_monitoring_package(sm_uuid), ScalarmFileName::monitoring_config)
    end

    def self.monitoring_package(arch)
      # TODO: monitoring packages local repo path
      File.join(Rails.root, 'public', 'scalarm_monitoring', arch, ScalarmFileName::monitoring_package)
    end

    def self.certificate
      Rails.application.secrets.certificate_path
    end

    def self.tmp_sim_certificate(sm_uuid)
      File.join(LocalAbsoluteDir::tmp_simulation_manager(sm_uuid), ScalarmFileName::remote_certificate)
    end

    def self.tmp_sim_config(sm_uuid)
      File.join(LocalAbsoluteDir::tmp_simulation_manager(sm_uuid), ScalarmFileName::sim_config)
    end

    def self.tmp_sim_zip(sm_uuid)
      File.join('/tmp', ScalarmFileName::tmp_sim_zip(sm_uuid))
    end

    def self.tmp_sim_code_zip(sm_uuid)
      File.join(LocalAbsoluteDir::tmp, "scalarm_simulation_manager_code_#{sm_uuid}.zip")
    end
  end

  module LocalAbsoluteDir
    def self.tmp_monitoring_package(sm_uuid)
      File.join(LocalAbsoluteDir::tmp, ScalarmDirName::tmp_monitoring_package(sm_uuid))
    end

    def self.tmp_simulation_manager(sm_uuid)
      File.join(LocalAbsoluteDir::tmp, ScalarmDirName::tmp_simulation_manager(sm_uuid))
    end

    def self.tmp_sim_code(sm_uuid)
      File.join(LocalAbsoluteDir::tmp, ScalarmDirName::tmp_sim_code(sm_uuid))
    end

    def self.simulation_manager_go(arch)
      File.join(Rails.root, 'public', 'scalarm_simulation_manager_go', arch)
    end

    def self.simulation_manager_ruby
      File.join(Rails.root, 'public', 'scalarm_simulation_manager_ruby')
    end

    def self.tmp
      '/tmp'
    end
  end

  module RemoteDir
    def self.scalarm_root
      'scalarm/'
    end

    def self.simulation_managers
      "#{scalarm_root}/simulation_managers/"
    end

    def self.monitoring
      "#{scalarm_root}/workers_monitor/"
    end
  end

  module ScalarmFileName
    def self.monitoring_config
      'monitoring_config.json'
    end

    def self.monitoring_binary
      'scalarm_monitoring'
    end

    def self.monitoring_package
      "#{monitoring_binary}.xz"
    end

    def self.remote_proxy
      'user_proxy.pem'
    end

    def self.remote_certificate
      'scalarm_certificate.pem'
    end

    def self.sim_config
      'config.json'
    end

    def self.tmp_sim_zip(sm_uuid)
      "scalarm_simulation_manager_#{sm_uuid}.zip"
    end

    def self.sim_log(sm_uuid)
      "scalarm_simulation_manager_#{sm_uuid}.log"
    end
  end

  module ScalarmDirName
    def self.tmp_monitoring_package(sm_uuid)
     "scalarm_monitoring_#{sm_uuid}"
    end

    def self.tmp_simulation_manager(sm_uuid)
      "scalarm_simulation_manager_#{sm_uuid}"
    end

    def self.tmp_sim_code(sm_uuid)
      "scalarm_simulation_manager_code_#{sm_uuid}"
    end
  end

  module RemoteHomePath
    def self.monitoring_config
      File.join(RemoteDir::monitoring, ScalarmFileName::monitoring_config)
    end

    def self.monitoring_binary
      File.join(RemoteDir::monitoring, ScalarmFileName::monitoring_binary)
    end

    def self.monitoring_package
      File.join(RemoteDir::monitoring, ScalarmFileName::monitoring_package)
    end

    def self.remote_monitoring_proxy
      File.join(RemoteDir::monitoring, ScalarmFileName::remote_proxy)
    end

    def self.remote_monitoring_certificate
      File.join(RemoteDir::monitoring, ScalarmFileName::remote_certificate)
    end

    def self.sim_log(sm_uuid)
      File.join(RemoteDir::simulation_managers, ScalarmFileName::sim_log(sm_uuid))
    end
  end

  module RemoteAbsolutePath
    def self.monitoring_config
      add_home_prefix RemoteHomePath::monitoring_config
    end

    def self.monitoring_binary
      add_home_prefix RemoteHomePath::monitoring_binary
    end

    def self.monitoring_package
      add_home_prefix RemoteHomePath::monitoring_package
    end

    def self.remote_monitoring_proxy
      add_home_prefix RemoteHomePath::remote_monitoring_proxy
    end

    def self.remote_monitoring_certificate
      add_home_prefix RemoteHomePath::remote_monitoring_certificate
    end

    def self.sim_log(sm_uuid)
      add_home_prefix RemoteHomePath::sim_log(sm_uuid)
    end

    def self.add_home_prefix(path)
      File.join('~', path)
    end
  end

  module Command
    def self.cd_to_simulation_managers(cmd)
      chain(
          cd(RemoteDir::simulation_managers),
          cmd
      )
    end
  end

end