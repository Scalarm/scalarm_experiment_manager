require File.expand_path('../boot', __FILE__)

#require 'rails/all'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module ScalarmExperimentManager
  class Application < Rails::Application
    config.r_interpreter = RinRuby.new(false)

    config.autoload_paths += %W(#{config.root}/app/models/infrastructure_facades #{config.root}/app/models/infrastructure_facades/amazon_credentials)
    # TODO this should be taken from the information service registration
    config.manager_id = 1
    config.experiment_seeks = {}
    config.session_threshold = 30*60 # max session time in seconds - currently it is 30 minutes
    config.force_ssl = (Rails.env == 'production') #this sets Secure attribute for cookies
    config.simulation_manager_version = :go # only :ruby or :go
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    # config.i18n.default_locale = :de

    config.ssh_exec_timeout_secs = 45
  end
end
