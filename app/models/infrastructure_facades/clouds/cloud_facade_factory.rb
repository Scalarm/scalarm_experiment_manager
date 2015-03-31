require 'singleton'

class CloudFacadeFactory < DependencyInjectionFactory
  include Singleton

  def initialize
    super(
        File.join(Rails.root, 'app/models/infrastructure_facades/clouds/providers'),
        'CloudClient',
        CloudFacade
    )
  end

  # Selects only Clouds, for which secrets are defined
  # @return [Hash<String, String>] full cloud name => short name
  # @return [Hash<String, String>] full cloud name => short name
  def provider_names_select(user_id)
    enabled_clouds = (client_classes.collect {|name, cc| [name, CloudFacade.new(cc)]}).select do |name, cf|
      cf.enabled_for_user? user_id
    end

    Hash[enabled_clouds.map {|name, client| [client.long_name, name]}]
  end

end
