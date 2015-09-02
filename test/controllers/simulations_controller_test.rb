require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'db_helper'

class SimulationsControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
    stub_authentication
  end

  def teardown
    super
  end

  # Tests registration of simulation without parameters and without executor name
  test 'successful registration of simulation should return HTTP code 200' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )

    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: {
                 entities: [
                     {
                         parameters: []
                     }
                 ]
             },
             format: :json
         }

    assert_response :success, response.body
  end

end
