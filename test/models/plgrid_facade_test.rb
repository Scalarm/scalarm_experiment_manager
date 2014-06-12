require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class CloudFacadeTest < MiniTest::Test

  require 'infrastructure_facades/infrastructure_errors'

  def test_schedule_invalid_credentials
    credentials = stub_everything 'credentials' do
      stubs(:invalid).returns(true)
    end
    cloud_client = stub_everything
    facade = CloudFacade.new(cloud_client)
    facade.stubs(:get_cloud_secrets).returns(credentials)

    assert_raises InfrastructureErrors::InvalidCredentialsError do
      facade.start_simulation_managers('u', 2, 'e')
    end
  end

end