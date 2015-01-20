module SSHAccessedInfrastructure
  include SharedSSH
  include ShellCommands

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
      File.join('/tmp', "scalarm_simulation_manager_#{sm_uuid}.zip")
    end
  end

  module LocalAbsoluteDir
    def self.tmp_monitoring_package(sm_uuid)
      File.join('/tmp', "scalarm_monitoring_#{sm_uuid}")
    end

    def self.tmp_simulation_manager(sm_uuid)
      File.join('/tmp', "scalarm_simulation_manager_#{sm_uuid}")
    end

    def self.simulation_manager_go(arch)
      File.join(Rails.root, 'public', 'scalarm_simulation_manager_go', arch)
    end

    def self.simulation_manager_ruby
      File.join(Rails.root, 'public', 'scalarm_simulation_manager_ruby')
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
      "#{scalarm_root}/monitoring/"
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

    def self.add_home_prefix(path)
      File.join('~', path)
    end
  end
end