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
        onsite_monitoring: '',
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
        onsite_monitoring: '',
        credentials_id: other_creds.id
    }

    other_records = facade.start_simulation_managers(user.id, 2, experiment.id, other_sim_params)

    # When
    queried_records = facade.query_simulation_manager_records(user.id, experiment.id, sim_params)

    # Then
    assert_equal (created_records.map { |r| r.id.to_s }).sort, (queried_records.map { |r| r.id.to_s }).sort
  end

  # Given:
  #   CloudFacade (amazon) creates simulation managers with:
  #   start_simulation_managers(user_id, instances_count, experiment_id, params)
  # When:
  #   The query_simulation_manager_records(user_id, experiment_id, params) is invoked
  # Then:
  #   It returns the same set of simulation manager records as start_simulation_managers
  test 'query_simulation_manager_records for amazon should return records which start_simulation_managers creates' do
    # Given
    user = ScalarmUser.new(login: 'test_user')
    user.save
    experiment = Experiment.new({})
    experiment.save
    facade = InfrastructureFacadeFactory.get_facade_for('amazon')
    cloud_secrets = stub_everything
    cloud_client = stub_everything do
      stubs(:image_exists?).returns(true)
    end
    facade.stubs(:get_cloud_secrets).with(user.id).returns(cloud_secrets)
    facade.stubs(:cloud_client_instance).with(user.id).returns(cloud_client)

    creds = CloudImageSecrets.new(
        user_id: user.id,
        image_identifier: 'foo',
        cloud_name: 'amazon'
    )
    creds.save

    sim_params = {
        "experiment_id"=>"564c4e6f369ffd0418000003",
        "infrastructure_name"=>"amazon",
        "job_counter"=>"1",
        "image_secrets_id"=>creds.id.to_s,
        "stored_security_group"=>"quicklaunch-1",
        "instance_type"=>"t1.micro",
        "time_limit"=>"15",
        "start_at"=>"",
        "commit"=>"Submit"
    }

    sim_params = ActiveSupport::HashWithIndifferentAccess.new(sim_params)

    facade.start_simulation_managers(user.id, 3, experiment.id, sim_params)
    created_records = facade.get_sm_records

    # Add some random simulation managers to test filtering
    other_creds = CloudImageSecrets.new(
        user_id: user.id,
        image_identifier: 'hello_world',
        cloud_name: 'amazon'
    )
    other_creds.save

    other_sim_params = {
        "experiment_id"=>"564c4e6f369ffd0418000003",
        "infrastructure_name"=>"amazon",
        "job_counter"=>"1",
        "image_secrets_id"=>other_creds.id.to_s,
        "stored_security_group"=>"quicklaunch-1",
        "instance_type"=>"t1.micro",
        "time_limit"=>"20",
        "start_at"=>"",
        "commit"=>"Submit"
    }

    other_records = facade.start_simulation_managers(user.id, 2, experiment.id, other_sim_params)

    # When
    queried_records = facade.query_simulation_manager_records(user.id, experiment.id, sim_params)

    # Then
    assert_equal (created_records.map { |r| r.id.to_s }).sort, (queried_records.map { |r| r.id.to_s }).sort
  end

end