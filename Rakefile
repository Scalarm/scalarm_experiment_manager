# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)
require File.expand_path('../app/models/load_balancer_registration.rb', __FILE__)

ScalarmExperimentManager::Application.load_tasks

LOCAL_MONGOS_PATH = 'bin/mongos'

# there is also amd64 by default build, but it is not required
REQUIRED_ARCHS = ['linux_386']


namespace :service do
  desc 'Start the service'
  task :start, [:debug] => [:ensure_config, :setup, :environment] do |t, args|
    puts 'puma -C config/puma.rb'
    %x[puma -C config/puma.rb]

    load_balancer_registration
    create_anonymous_user

    # start monitoring only if there is configuration
    if Rails.application.secrets.monitoring
      monitoring_probe('start')
    else
      puts 'Monitoring probe disabled due to lack of configuration'
    end
  end

  desc 'Stop the service'
  task :stop, [:debug] => [:environment] do |t, args|
    puts 'pumactl -F config/puma.rb -T scalarm stop'
    %x[pumactl -F config/puma.rb -T scalarm stop]

    if Rails.application.secrets.monitoring
      monitoring_probe('stop')
    else
      puts 'Monitoring probe will not be stopped due to lack of configuration'
    end

    load_balancer_deregistration
  end

  desc 'Restart the service'
  task restart: [:stop, :start] do
  end

  desc 'Removing unnecessary digests on production'
  task non_digested: :environment do
    Rake::Task['assets:precompile'].execute
    assets = Dir.glob(File.join(Rails.root, 'public/assets/**/*'))
    regex = /(-{1}[a-z0-9]{32}*\.{1}){1}/
    assets.each do |file|
      next if File.directory?(file) || file !~ regex

      source = file.split('/')
      source.push(source.pop.gsub(regex, '.'))

      non_digested = File.join(source)
      FileUtils.cp(file, non_digested)
    end
  end

  desc 'Create default configuration files if these do not exist'
  task :ensure_config do
    copy_example_config_if_not_exists('config/secrets.yml')
    copy_example_config_if_not_exists('config/puma.rb')
  end

  desc 'Downloading and installing dependencies'
  task :setup, [:debug] => [:environment] do
    puts 'Setup started'
    #get_monitoring unless check_monitoring
    #get_simulation_managers_go unless check_sim_go
    #get_simulation_manager_ruby unless check_sim_ruby
    install_r_libraries

    _validate_service
    puts 'Setup finished'
  end

  desc 'Update Monitoring and SimulationManager packages from binary repo'
  task update: ['get:monitoring', 'get:simulation_managers'] do
  end

  desc 'Check dependencies'
  task :validate do
    begin
      _validate_service
    rescue Exception => e
      puts "Error on validation, please read documentation and run service:setup"
      raise
    end
  end

end


namespace :build do
  desc 'Building Simulation Managers and Monitoring packages from sources'
  task all: [:monitoring, :simulation_managers] do
    puts 'Getting and building Scalarm modules from sources'
  end

  task :monitoring do
    puts 'Building Monitoring'
    build_monitoring
  end

  task :simulation_managers do
    puts 'Building Simulation Managers packages'
    build_simulation_managers_go
  end
end

namespace :get do
  task all: [:monitoring, :simulation_managers, :mongos] do
    puts 'Getting Scalarm packages'
  end

  task :monitoring do
    get_monitoring
  end

  task :simulation_managers do
    get_simulation_managers_go
    get_simulation_manager_ruby
  end

  task :mongos do
    install_mongodb
  end
end

namespace :db_router do
  desc 'Start MongoDB router'
  task :start, [:debug] => [:setup] do |t, args|
    config = load_config
    information_service = create_information_service(config)

    config_services = information_service.get_list_of('db_config_services')
    puts "Config services: #{config_services.inspect}"
    if config_services.blank?
      puts 'There are no config services available - will not start router'
    else
      config_service_url = config_services.sample
      start_router(config_service_url) if config_service_url
    end
  end

  task :stop, [:debug] => [] do |t, args|
    stop_router
  end

  task :setup do
    install_mongodb unless mongos_path
    _validate_db_router
  end

  desc 'Check dependencies for db_router'
  task :validate do
    begin
      _validate_db_router
    rescue Exception => e
      puts "Error on validation, please read documentation and run db_router:setup"
      raise
    end
  end
end

namespace :load_balancer do
  desc 'Registration to load balancer'
  task :register do
    load_balancer_registration
  end

  desc 'Deregistration from load balancer'
  task :deregister do
    load_balancer_deregistration
  end
end


# ================ UTILS
def start_router(config_service_url)
  bin = mongos_path
  puts "Using: #{bin}"
  puts `#{bin} --version 2>&1`
  router_cmd = "#{mongos_path} --bind_ip localhost --configdb #{config_service_url} --logpath log/db_router.log --fork --logappend"
  puts router_cmd
  puts %x[#{router_cmd}]
end

def stop_router
  proc_name = "#{mongos_path} .*"
  out = %x[ps aux | grep "#{proc_name}"]
  processes_list = out.split("\n").delete_if { |line| line.include? 'grep' }

  processes_list.each do |process_line|
    pid = process_line.split(' ')[1]
    puts "kill -15 #{pid}"
    system("kill -15 #{pid}")
  end
end

def monitoring_probe(action)
  probe_pid_path = File.join(Rails.root, 'tmp', 'scalarm_monitoring_probe.pid')

  case action
    when 'start'
      Process.daemon(true)
      monitoring_job_pid = fork do
        # requiring all class from the model
        Dir[File.join(Rails.root, 'app', 'models', '**/*.rb')].each do |f|
          require f
        end

        probe = MonitoringProbe.new
        probe.start_monitoring

        ExperimentWatcher.watch_experiments
        InfrastructureFacadeFactory.start_all_monitoring_threads.each &:join
      end

      IO.write(probe_pid_path, monitoring_job_pid)

      Process.detach(monitoring_job_pid)
    when
    if File.exist?(probe_pid_path)
      monitoring_job_pid = IO.read(probe_pid_path)
      Process.kill('TERM', monitoring_job_pid.to_i)
    end
  end
end

def create_anonymous_user
  unless Rails.env.test?
    require 'utils'

    # anonymous_login and anonymous_password moved to secrets.yml
    #config = Utils::load_config
    config = Rails.application.secrets.anonymous_user

    if config
      anonymous_login = config['login']
      anonymous_password = config['password']

      if anonymous_login and anonymous_password and not ScalarmUser.find_by_login(anonymous_login)
        Rails.logger.debug "Creating anonymous user with login: #{anonymous_login}"
        user = ScalarmUser.new(login: anonymous_login)
        user.password = anonymous_password
        user.save
      end
    end
  end
end

def get_mongodb(version='2.6.5')
  os, arch = os_version
  mongo_name = "mongodb-#{os}-#{arch}-#{version}"
  download_file_https('fastdl.mongodb.org', "/#{os}/mongodb-#{os}-#{arch}-#{version}.tgz", "#{mongo_name}.tgz")
  mongo_name
end

def build_monitoring
  puts 'Invoking Monitoring package install script...'
  `./build_monitoring.sh`
  raise 'Monitoring build failed' unless $?.to_i == 0
end

def get_monitoring
  `./get_monitoring.sh`
  raise 'Getting Monitoring from repository failed' unless $?.to_i == 0
end

def build_simulation_managers_go
  `./build_simulation_managers.sh`
  raise 'Simulation Managers build failed' unless $?.to_i == 0
end

def get_simulation_managers_go
  `./get_simulation_managers.sh`
  raise 'Getting simulation managers in Go from repository failed' unless $?.to_i == 0
end

def get_simulation_manager_ruby
  `git submodule init && git submodule update`
  raise 'Getting ScalarmSimulationManager submodule failed' unless $?.to_i == 0
end

def install_r_libraries
  puts 'Checking R libraries...'
  Rails.configuration.r_interpreter.eval(
      ".libPaths(c(\"#{Dir.pwd}/r_libs\", .libPaths()))
    if(!require(AlgDesign, quietly=TRUE)){
      install.packages(\"AlgDesign\", repos=\"http://cran.rstudio.com/\")
    }")
end

def install_mongodb
  puts 'Downloading MongoDB...'
  base_name = get_mongodb
  puts 'Unpacking MongoDB and copying files...'
  `tar -zxvf #{base_name}.tgz`
  raise "Cannot unpack #{base_name}.tgz archive" unless $?.to_i == 0
  `cp #{base_name}/bin/mongos bin/mongos`
  raise "Cannot copy #{base_name}/bin/mongos file" unless $?.to_i == 0
  `rm -r #{base_name} #{base_name}.tgz`
  puts 'Installed MongoDB mongos in Scalarm directory'
end

def os_version
  require 'rbconfig'
  os_arch = RbConfig::CONFIG['arch']
  os = case os_arch
    when /darwin/
      'osx'
    when /cygwin|mswin|mingw|bccwin|wince|emx/
      'win32'
    else
      'linux'
  end
  arch = case os_arch
    when /x86_64/
      'x86_64'
    when /i686/
      'i686'
  end
  [os, arch]
end

def download_file_https(domain, path, name)
  require 'net/https'
  address = "https://#{domain}/#{path}"
  puts "Fetching #{address}..."
  Net::HTTP.start(domain) do |http|
      resp = http.get(path)
      open(name, "wb") do |file|
          file.write(resp.body)
      end
  end
  puts "Downloaded #{address} -> #{name}"
  name
end

def _validate_db_router
  print 'Checking bin/mongos... '
  raise "No /bin/mongos file found and no mongos in PATH" unless mongos_path
  puts 'OK'
end

def _validate_service
  #print 'Checking Go monitoring packages...'
  #raise "No Scalarm Monitoring packages found" unless check_monitoring
  #puts 'OK'
  #print 'Checking Go Simulation Manager...'
  #raise "No Scalarm Simulation Manager packages found (Go version)" unless check_sim_go
  #puts 'OK'
  #print 'Checking Ruby Simulation Manager...'
  #raise "No Scalarm Simulation Manager packages found (Ruby version)" unless check_sim_ruby
  #puts 'OK'

  %w(R zip).each do |cmd|
    check_for_command(cmd)
  end

  check_for_command_alt %w(mpstat iostat)

  true
end

def check_for_command_alt(commands)
  any_cmd = commands.any? do |cmd|
    begin
      check_for_command(cmd)
      true
    rescue StandardError
      puts 'Not found. Checking alternatives...'
      false
    end
  end

  raise 'Some dependecies are missing.' unless any_cmd
end

def check_for_command(command)
  print "Checking for #{command}... "
  `which #{command}`
  unless $?.to_i == 0
    raise "No #{command} found in PATH. Please install it."
  end
  puts 'OK'
end

def mongos_path
  `ls #{LOCAL_MONGOS_PATH} >/dev/null 2>&1`
  if $?.to_i == 0
    LOCAL_MONGOS_PATH
  else
    `which mongos > /dev/null 2>&1`
    if $?.to_i == 0
      'mongos'
    else
      nil
    end
  end
end

def check_monitoring
  REQUIRED_ARCHS.all? do |arch|
    `ls public/scalarm_monitoring/#{arch}/scalarm_monitoring.xz`
    $?.to_i == 0
  end
end

def check_sim_go
  REQUIRED_ARCHS.all? do |arch|
    `ls public/scalarm_simulation_manager_go/#{arch}/scalarm_simulation_manager.xz`
    $?.to_i == 0
  end
end

def check_sim_ruby
  `ls public/scalarm_simulation_manager_ruby/simulation_manager.rb`
  $?.to_i == 0
end

def load_balancer_registration
  unless Rails.application.secrets.include? :load_balancer
    puts 'There is no configuration for load balancer in secrets.yml - LB registration will be disabled'
    return
  end
  unless Rails.env.test? or Rails.application.secrets.load_balancer["disable_registration"]
    LoadBalancerRegistration.register(Rails.application.secrets.load_balancer["address"])
  else
    puts 'load_balancer.disable_registration option is active'
  end
end

def load_balancer_deregistration
  unless Rails.application.secrets.include? :load_balancer
    puts 'There is no configuration for load balancer in secrets.yml - LB deregistration will be disabled'
    return
  end
  unless Rails.env.test? or Rails.application.secrets.load_balancer["disable_registration"]
    LoadBalancerRegistration.deregister(Rails.application.secrets.load_balancer["address"])
  else
    puts 'load_balancer.disable_registration option is active'
  end
end

def copy_example_config_if_not_exists(base_name, prefix='example')
  config = base_name
  example_config = "#{base_name}.example"

  unless File.exists?(config)
    puts "Copying #{example_config} to #{config}"
    FileUtils.cp(example_config, config)
  end
end

def load_config
  YAML.load(ERB.new(File.read("#{Rails.root}/config/secrets.yml")).result)[ENV['RAILS_ENV'] || 'development']
end

def create_information_service(config)
  Scalarm::ServiceCore::InformationService.new(
    config['information_service_url'],
    config['information_service_user'],
    config['information_service_pass'],
    !!config['information_service_development']
  )
end
