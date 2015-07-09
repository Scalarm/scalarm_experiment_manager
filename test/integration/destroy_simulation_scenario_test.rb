require 'test_helper'
require 'json'
require 'db_helper'

class DestroySimulationScenarioTest < ActionDispatch::IntegrationTest
  include DBHelper

  OWNER_NAME = 'owner'
  OWNER_PASSWORD = 'owner_password'
  COWORKER_NAME = 'coworker'
  COWORKER_PASSWORD = 'coworker_password'

  def setup
    super
    # create two users, log in one and set sample shared experiment
    @owner = ScalarmUser.new({login: OWNER_NAME})
    @owner.password = OWNER_PASSWORD
    @owner.save

    @coworker = ScalarmUser.new({login: COWORKER_NAME})
    @coworker.password = COWORKER_PASSWORD
    @coworker.save
    post login_path, username: COWORKER_NAME, password: COWORKER_PASSWORD

    @simulation_scenario = Simulation.new({user_id: @owner.id, shared_with: [@coworker.id]})
    @simulation_scenario.save

    # mock information service
    information_service = mock
    information_service.stubs(:get_list_of).returns([])
    information_service.stubs(:sample_public_url).returns(nil)
    InformationService.stubs(:instance).returns(information_service)
  end

  test 'unsuccessful destroying simulation scenario by non-owner coworker with html response' do

    assert_no_difference 'Simulation.count' do
      delete "simulation_scenarios/#{@simulation_scenario.id}"
    end

    assert_redirected_to simulations_path
    assert_equal flash['error'], "Simulation scenario with id '#{@simulation_scenario.id}' is not owned by '#{COWORKER_NAME}'"
  end
end
