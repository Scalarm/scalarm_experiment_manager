require "rubygems"
require "rinruby"
require "mongo"
require "yaml"

require File.expand_path('../boot', __FILE__)

require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module SimulationManager
  class Application < Rails::Application
    config.simulation_scenarios = {}
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/app/models/infrastructure_facades #{config.root}/app/models/infrastructure_facades/amazon_credentials)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Scalarm Experiment Manager SPECIFIC CONFIGURATION
    @config_hash = YAML.load(File.open(File.join(Rails.root, "config", "scalarm_experiment_manager.yml")))

    if @config_hash.has_key?("cache_store_url")
      config.cache_store = @config_hash["cache_store_type"].to_sym, @config_hash["cache_store_url"]
    else
      config.cache_store = @config_hash["cache_store_type"].to_sym
    end

    config.scenarios_path = @config_hash["scenarios_path"]
    config.eusas_repo_path = @config_hash["eusas_repo_path"]
    config.eusas_data_path = @config_hash["eusas_data_path"]

    config.eusas_rinruby = RinRuby.new(false)

    config.amazon_monitoring_thread_activated = false
    config.plgrid_monitoring_thread_activated = false
    #puts("server_port : #{ENV["EUSAS_SERVER_PORT"]}")
    config.manager_id = nil
    if File.exists?("tmp/manager_#{ENV["EUSAS_SERVER_PORT"]}.txt")
      File.open("tmp/manager_#{ENV["EUSAS_SERVER_PORT"]}.txt"){|f| config.manager_id = f.readline.to_i}
    end

    config.experiment_seeks = {}
    #puts("Manager ID: #{config.manager_id}")
  end
end
