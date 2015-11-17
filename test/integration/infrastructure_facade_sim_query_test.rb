require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'

class InfrastructureFacadeSimQueryTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  # Given:
  #   PrivateMachineFacade creates simulation managers with:
  #   start_simulation_managers(user_id, instances_count, experiment_id, params)
  # When:
  #   The query_simulation_manager_records(user_id, experiment_id, params) is invoked
  # Then:
  #   It returns the same set of simulation manager records as start_simulation_managers
  test 'query_simulation_manager_records for private_machine should return records which start_simulation_managers creates' do
    # Given
    user = ScalarmUser.new(login: 'test_user')
    user.save
    experiment = Experiment.new({})
    experiment.save
    facade = InfrastructureFacadeFactory.get_facade_for('private_machine')
    ssh_stub = stub_everything('ssh') do
      stubs(:exec!).returns('')
    end
    facade.stubs(:shared_ssh_session).returns(ssh_stub)

    creds = PrivateMachineCredentials.new(user_id: user.id)
    creds.save

    sim_params = {
        time_limit: '99',
        start_at: '',
        onsite_monitoring: 'off',
        credentials_id: creds.id
    }

    sim_params = ActiveSupport::HashWithIndifferentAccess.new(sim_params)

    facade.start_simulation_managers(user.id, 3, experiment.id, sim_params)
    created_records = facade.get_sm_records

    # Add some random simulation managers to test filtering
    other_creds = PrivateMachineCredentials.new(user_id: user.id)
    other_creds.save
    other_sim_params = {
        time_limit: '10',
        start_at: '',
        onsite_monitoring: 'off',
        credentials_id: other_creds.id
    }

    other_records = facade.start_simulation_managers(user.id, 2, experiment.id, other_sim_params)

    # When
    queried_records = facade.query_simulation_manager_records(user.id, experiment.id, sim_params)

    # Then
    assert_equal (created_records.map { |r| r.id.to_s }).sort, (queried_records.map { |r| r.id.to_s }).sort
  end

end