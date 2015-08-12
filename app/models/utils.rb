require 'json'
require 'scalarm/service_core/utils'

module Utils

  # extend this Utils with Scalarm::ServiceCore::Utils module methods
  class << self
    Scalarm::ServiceCore::Utils.singleton_methods.each do |m|
      define_method m, Scalarm::ServiceCore::Utils.method(m).to_proc
    end
  end

  def self.load_config
    # moved to secrets.yml
    # config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))

    Rails.application.secrets
  end

end