# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

ScalarmExperimentManager::Application.load_tasks

namespace :service do
  desc 'Start the service'
  task :start => :environment do
    #config = YAML::load(File.open(File.join(Rails.root, 'config', 'scalarm.yml')))
    #puts "thin start -d -C config/thin.yml"
    #%x[thin start -d -C config/thin.yml]
    puts 'pumactl -F config/puma.rb -T scalarm start'
    %x[pumactl -F config/puma.rb -T scalarm start]
  end

  desc 'Stop the service'
  task :stop => :environment do
    #%x[thin stop -C config/thin.yml]
    #%x[kill -9 $(ps aux | grep 'thin server (/tmp/scalarm_experiment_manager.sock)' | awk '{print $2}')]
    puts 'pumactl -F config/puma.rb -T scalarm stop'
    %x[pumactl -F config/puma.rb -T scalarm stop]
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

