require 'test_helper'
require 'db_helper'

class SimCleanUpTest < ActionDispatch::IntegrationTest
  include DBHelper

  USER_NAME = 'user'
  PASSWORD = 'password'
  DUMMY = 'dummy'

  def setup
    super
    user = ScalarmUser.new({login: USER_NAME})
    user.password = PASSWORD
    user.save
    post login_path, username: USER_NAME, password: PASSWORD

    @simulation = Simulation.new(name: 'name', description: 'description',
                                input_parameters: {}, input_specification: [])
    @simulation.user_id = user.id
    @simulation.save

    @experiment = Experiment.new({})
    @experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, [], [])
    @experiment.save
    @experiment_id = @experiment.id

    infrastructure = InfrastructureFacadeFactory.get_facade_for(DUMMY)
    @record = infrastructure.start_simulation_managers(user.id, 1, @experiment.id, {}).first
    @record_id = @record.id

    @simulation_run = @experiment.create_new_simulation(1)
    @simulation_run.sm_uuid = @record.sm_uuid
    @simulation_run.save
    @simulation_run_id = @simulation_run.id

    DummyRecord.any_instance.stubs(:get_current_simulation_run).returns(@simulation_run)

    @temp_pass = SimulationManagerTempPassword.create_new_password_for(@record.sm_uuid, @record.experiment_id)
    @temp_pass.save
  end

  test "rollback simulation on stop simulation manager by API" do
    assert_not Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id).to_sent,
               'Simulation run should not be in to sent state before rollback'
    post simulation_manager_command_infrastructure_path, command: 'stop',
         record_id: @record_id, infrastructure_name: DUMMY
    assert_nil Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id),
           'Simulation run should be rolled back after executing stop command on SiM'
  end

  test "rollback simulation on stop simulation manager" do
    assert_not Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id).to_sent,
               'Simulation run should not be in to sent state before rollback'

    facade = InfrastructureFacadeFactory.get_facade_for(DUMMY)
    record = facade.get_sm_record_by_id(@record_id)
    facade.yield_simulation_manager(record)  do |sm|
      sm.stop
    end
    assert_nil Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id),
           'Simulation run should be rolled back after executing stop command on SiM'
  end

  test "rollback simulation on destroy_record simulation manager by API" do
    assert_not Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id).to_sent,
               'Simulation run should not be in to sent state before rollback'
    post simulation_manager_command_infrastructure_path, command: 'destroy_record',
         record_id: @record_id, infrastructure_name: DUMMY
    assert_nil Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id),
           'Simulation run should be rolled back after executing destroy_record command on SiM'
  end

  test "rollback simulation on destroy_record simulation manager" do
    assert_not Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id).to_sent,
               'Simulation run should not be in to sent state before rollback'
    facade = InfrastructureFacadeFactory.get_facade_for(DUMMY)
    record = facade.get_sm_record_by_id(@record_id)
    facade.yield_simulation_manager(record)  do |sm|
      sm.destroy_record
    end
    assert_nil Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id),
           'Simulation run should be rolled back after executing destroy_record command on SiM'
  end

  test "clean up on SiM error" do
    # given
    assert_not Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id).to_sent,
               'Simulation run should not be in to sent state before rollback'
    assert_not_nil SimulationManagerTempPassword.find_by_id(@temp_pass.id)

    # when
    facade = InfrastructureFacadeFactory.get_facade_for(DUMMY)
    record = facade.get_sm_record_by_id(@record_id)
    facade.yield_simulation_manager(record)  do |sm|
      sm.record.store_error('bad_one')
    end

    # then
    assert_nil Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id),
           'Simulation run should be rolled back after executing destroy_record command on SiM'
    assert_nil SimulationManagerTempPassword.find_by_id(@temp_pass.id)
  end

  test "no simulation run duplication after getting rolled back simulation run" do
    # given
    stub_authentication
    @experiment.simulation_input = [{
                                     'entities' => [{
                                       'parameters' => [{
                                         'id' => 'param',
                                         'label' => 'param',
                                         'type' => 'integer',
                                         'min' => 0,
                                         'max' => 1,
                                         'with_default_value' => false,
                                         'index' => 1,
                                         'value' => 0,
                                         'parametrizationType' => 'range',
                                         'step' => 1,
                                         'in_doe' => false
                                       }]
                                     }]
                                   }]
    @experiment.scheduling_policy = 'sequential_forward'
    @experiment.is_running = true
    @experiment.size = 2
    @experiment.save
    @user.stubs(:experiments).returns(Experiment.where(id: @experiment_id))
    assert_equal 1, Experiment.find_by_id(@experiment_id).simulation_runs.count
    assert_not Experiment.find_by_id(@experiment_id).simulation_runs.find_by_id(@simulation_run_id).to_sent,
               'Simulation run should not be in to sent state before rollback'

    # when
    @simulation_run.rollback!
    get next_simulation_experiment_path id: @experiment_id, format: :json

    # then
    assert_equal 1, Experiment.find_by_id(@experiment_id).simulation_runs.count
  end
end
