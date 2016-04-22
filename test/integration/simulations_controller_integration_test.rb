require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

require 'db_helper'
require 'controller_integration_test_helper'

class SimulationsControllerIntegrationTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!
  end

  def teardown
    super
  end

  test 'simulations GET index should return simulation scenarios id accessible by user' do

    simulation = Simulation.new({
         'name' => 'test',
         'user_id' => @user.id,
         'created_at' => Time.now
     })
    simulation.save

    simulation2 = Simulation.new({
        'name' => 'test2',
        'user_id' => @user.id,
        'created_at' => Time.now
    })
    simulation2.save

    #test json response with valid ids
    get 'simulation_scenarios', format: :json
    body = response.body
    sim_hash = JSON.parse(body)
    assert_equal 2, sim_hash["simulation_scenarios"].count, sim_hash
    assert_includes sim_hash["simulation_scenarios"], simulation.id.to_s


    ## test for hmtl response
    get 'simulation_scenarios'
    assert_response 200, response.body
    assert_equal "text/html; charset=utf-8", response["Content-Type"]

  end

end
