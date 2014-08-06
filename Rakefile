# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

ScalarmExperimentManager::Application.load_tasks

namespace :service do
  desc 'Start the service'
  task :start, [:debug] => [:environment] do |t, args|
    puts 'puma -C config/puma.rb'
    %x[puma -C config/puma.rb]

    monitoring_probe('start')
  end

  desc 'Stop the service'
  task :stop, [:debug] => [:environment] do |t, args|
    puts 'pumactl -F config/puma.rb -T scalarm stop'
    %x[pumactl -F config/puma.rb -T scalarm stop]

    monitoring_probe('stop')
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

end

namespace :db_router do
  desc 'Start MongoDB router'
  task :start, [:debug] => [:environment] do |t, args|
    information_service = InformationService.new

    config_services = information_service.get_list_of('db_config_services')
    puts "Config services: #{config_services.inspect}"
    unless config_services.blank?
      config_service_url = config_services.sample
      start_router(config_service_url) if config_service_url
    end
  end

  task :stop, [:debug] => [:environment] do |t, args|
    stop_router
  end
end


# ================ UTILS
def start_router(config_service_url)
  router_cmd = "./bin/mongos --bind_ip localhost --configdb #{config_service_url} --logpath log/db_router.log --fork --logappend"
  puts router_cmd
  puts %x[#{router_cmd}]
end

def stop_router
  proc_name = "./mongos .*"
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

  if action == 'start'
    Process.daemon(true)
    monitoring_job_pid = fork {
      require 'monitoring_probe'

      probe = MonitoringProbe.new
      probe.start_monitoring

      ExperimentWatcher.watch_experiments
      InfrastructureFacadeFactory.start_all_monitoring_threads.each &:join
    }

    IO.write(probe_pid_path, monitoring_job_pid)

    Process.detach(monitoring_job_pid)

  elsif action == 'stop'
    if File.exist?(probe_pid_path)
      monitoring_job_pid = IO.read(probe_pid_path)
      Process.kill('TERM', monitoring_job_pid.to_i)
    end
  end

end
