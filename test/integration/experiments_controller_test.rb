require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentsControllerTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!
  end

  def teardown
    super
  end

  test 'one custom experiment on list' do
    simulation = stub_everything 'simulation' do
      stubs(:input_specification).
          returns([
                      {'entities' => [{'parameters' => []}]}
                  ])
      stubs(:input_parameters).returns({})
    end
    exp = ExperimentFactory.create_custom_points_experiment(@user.id, simulation, name: 'exp')
    exp.save

    get experiments_path, format: :json
    body = response.body
    hash_resp = JSON.parse(body)
    assert_equal 'ok', hash_resp['status'], hash_resp
    assert_equal 1, hash_resp['running'].count, hash_resp
    assert_equal exp.id.to_s, hash_resp['running'][0], hash_resp
  end

end
