require 'singleton'

class CloudFacadeFactory < DependencyInjectionFactory
  include Singleton

  def initialize
    super(
        File.join(Rails.root, 'app/models/infrastructure_facades/clouds/providers'),
        'CloudClient',
        Scalarm::CloudFacade
    )
  end

  # Selects only Clouds, for which secrets are defined
  # @return [Hash<String, String>] full cloud name => short name
  def provider_names_select(user_id)
    clouds_with_creds = client_classes.select do |name, _|
      not CloudSecrets.find_by_query('cloud_name'=>name, 'user_id'=>user_id).nil?
    end

    Hash[clouds_with_creds.map {|name, client| [client.long_name, name]}]
  end

end
