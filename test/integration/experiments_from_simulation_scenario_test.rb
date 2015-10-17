require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentsFromSimulationScenarioTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!
  end

  def teardown
    super
  end

  test 'get experiment ids from one simulation scenario' do

    simulation = Simulation.new({
                                    'name' => 'test',
                                    'user_id' => @user.id,
                                    'created_at' => Time.now
                                })
    simulation.save

    exp = ExperimentFactory.create_experiment(@user.id, simulation, name: 'exp')
    exp.save
    exp2 = ExperimentFactory.create_experiment(@user.id, simulation, name: 'exp2')
    exp2.save

    get "simulation_scenarios/#{simulation.id}/experiments", format: :json
    body = response.body
    hash_resp = JSON.parse(body)
    assert_equal 'ok', hash_resp['status'], hash_resp
    assert_equal 2, hash_resp['experiments'].count, hash_resp
    assert_equal exp.id.to_s, hash_resp['experiments'][0], hash_resp
  end

end
