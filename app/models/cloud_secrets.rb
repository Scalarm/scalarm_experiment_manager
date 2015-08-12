# Fields:
# cloud_name: string - cloud name, e.g. 'amazon'
# user_id: ScalarmUser id who has this secrets
#
# other fields are user defined and should be of String class to enable encryption!

require 'infrastructure_facades/infrastructure_errors'
require 'scalarm/database/model'

class CloudSecrets < Scalarm::Database::Model::CloudSecrets
  attr_join :user, ScalarmUser

  def valid?
    begin
      # do not rescue from all exceptions raised from factory related operations
      client_class = CloudFacadeFactory.instance.client_classes[cloud_name]
      client = client_class.new(self)
      raise InfrastructureErrors::NoSuchInfrastructureError.new(cloud_name) if client_class.nil?
      begin
        client.valid_credentials?
      rescue
        false
      end
    rescue InfrastructureErrors::InvalidCredentialsError
      false
    end
  end
end