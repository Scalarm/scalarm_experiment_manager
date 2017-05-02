require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'capybara/poltergeist'


require 'db_helper'
require 'controller_integration_test_helper'

class ExperimentMonitoringViewTest < ActionDispatch::IntegrationTest
  include DBHelper
  include ControllerIntegrationTestHelper

  def setup
    super
    authenticate_session!
    Capybara.current_driver = Capybara.javascript_driver
    login

    @simulation = Simulation.new({name: 'test_simulation', user_id: @user.id, created_at: Time.now})
    @simulation.input_specification = [{"entities" =>
                                            [{"parameters" => [{"id" => "parameter1", "label" => "Param 1",
                                                                "type" => "float", "min" => "0", "max" => "1000"},
                                                               {"id" => "parameter2", "label" => "Param 2",
                                                                "type" => "float", "min" => -100, "max" => 100}]}]}]

    @simulation.save

    @experiment_params = {"is_running" => true, "user_id" => @user.id,
                          "start_at" => Time.now,
                          "replication_level" => 1,
                          "time_constraint_in_sec" => 3300,
                          "scheduling_policy" => "monte_carlo",
                          "name" => "multi",
                          "description" => "",
                          "parameters_constraints" => [],
                          "doe_info" => [],
                          "experiment_input" => [{"entities" =>
                                                      [{"parameters" => [{"id" => "parameter1", "label" => "Param 1",
                                                                          "parametrization_type" => "range", "type" => "float", "min" => "0",
                                                                          "max" => "1000", "with_default_value" => false, "index" => 1,
                                                                          "parametrizationType" => "range", "step" => "200.0", "in_doe" => false},
                                                                         {"id" => "parameter2", "label" => "Param 2", "parametrization_type" => "range",
                                                                          "type" => "float", "min" => -100, "max" => 100, "with_default_value" => false,
                                                                          "index" => 2, "parametrizationType" => "value", "value" => "-100", "in_doe" => false}]}]}],
                          "labels" => "parameter1,parameter2", "simulation_id" => @simulation.id}

    @experiment = Experiment.new(@experiment_params)
    @experiment.save
  end

  def teardown
    super
  end

  test 'experiment monitoring view should display default analysis panel with histogram analysis' do
    visit(experiment_path(@experiment.id))

    assert_text find('.analyses-panel .histogram-analysis'), 'Histogram'
  end

  private

  def login
    visit(root_path)
    p page.has_selector?('#login_username_button')
    click_link('login_username_button')
    fill_in('Login', with: @user.login)
    fill_in('password', with: 'password')
    click_on('Login')
  end

end