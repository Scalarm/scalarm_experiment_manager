require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class CloudFacadeTest < MiniTest::Test

  def setup
    cloud_client = stub_everything
    @facade = CloudFacade.new(cloud_client)
    @facade.stubs(:logger).returns(stub_everything)
  end

  def stub_record(user_id, experiment_id)
    r = Object.new
    r.stubs(:user_id).returns(user_id)
    r.stubs(:experiment_id).returns(experiment_id)
    r
  end

  # TODO
  def test_get_infrastructure_sm_records
    skip('TODO')

    # given
    user1_id = 1
    user2_id = 2

    experiment1_id = 'a'
    experiment2_id = 'b'

    cloud_name = 'c1'

    cloud_client = Object.new
    cloud_client.stubs(:short_name).returns('c1')
    cloud_client.stubs(:long_name).returns('Cloud One')

    Scalarm::CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user1_id})
      .returns([
        stub_record(user1_id, experiment1_id),
        stub_record(user1_id, experiment1_id),
        stub_record(user1_id, experiment2_id)
               ])

    Scalarm::CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user2_id})
    .returns([
                 stub_record(user2_id, experiment1_id),
                 stub_record(user2_id, experiment2_id)
             ])

    Scalarm::CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user1_id, experiment_id: nil})
      .returns(CloudVmRecord.find_all_by_query({cloud_name: cloud_name, user_id: user1_id}))

    Scalarm::CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user1_id, experiment_id: experiment1_id})
    .returns([
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment1_id)
             ])


    facade = CloudFacade.new(cloud_client)

    # when
    user1_records = facade.get_sm_records(user1_id)
    user1_exp1_records = facade.get_sm_records(user1_id, experiment1_id)

    # then
    assert_equal 3, user1_records.count
    assert user1_records.all? {|r| r.user_id == user1_id}

    assert_equal 2, user1_exp1_records.count
    assert user1_exp1_records.all? {|r| r.user_id == user1_id and r.experiment_id == experiment1_id}
  end

  def test_simulation_manager_install
    record = stub_everything 'record' do
      stubs(:vm_id).returns('a')
      expects(:update_ssh_address!).once
      stubs(:time_limit_exceeded?).returns(false)
      stubs(:experiment_end?).returns(false)
      stubs(:init_time_exceeded?).returns(false)
    end

    InfrastructureFacade.expects(:prepare_configuration_for_simulation_manager).once

    cloud_client = mock 'cloud_client' do
      stubs(:vm_instance).returns(stub_everything)
    end

    facade = CloudFacade.new(cloud_client)

    facade.stubs(:logger).returns(stub_everything)
    facade.expects(:cloud_client_instance).returns(cloud_client).once
    facade.expects(:log_exists?).returns(false).once
    facade.expects(:send_and_launch_sm).returns(10).once
    facade.expects(:simulation_manager_stop).never

    # EXECUTE
    facade._simulation_manager_install(record)

  end

  # TODO
  def test_remove_cloud_secrets
    skip("TODO")

    cloud_client = mock 'cloud_client' do
      stubs(:vm_instance).returns(stub_everything)
    end
    facade = CloudFacade.new(cloud_client)

    cloud_secrets = stub_everything do
      expects(:destroy).once
      stubs(:user_id).returns('user_id_1')
    end

    CloudSecrets.expects(:find_by_user_id).with('user_id_1').returns(cloud_secrets).once

    facade.remove_credentials(nil, 'user_id_1', 'secrets')
  end

  require 'infrastructure_facades/infrastructure_errors'

  def test_schedule_invalid_credentials
    user_id = mock 'user_id'
    credentials = stub_everything 'credentials' do
      stubs(:invalid).returns(true)
    end
    cloud_client = stub_everything
    facade = CloudFacade.new(cloud_client)
    facade.stubs(:get_cloud_secrets).returns(credentials)

    assert_raises InfrastructureErrors::InvalidCredentialsError do
      facade.cloud_client_instance(user_id)
    end
  end

  def test_resource_status_not_avail
    client = stub_everything 'client'
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).raises(StandardError.new 'error creating client')

    status = facade._simulation_manager_resource_status(record)

    assert_equal :not_available, status
  end

  def test_resource_status_avail
    client = stub_everything 'client' do
      stubs(:valid_credentials?).returns(true)
    end
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).returns(client)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :available, status
  end

  def test_resource_status_init1
    vm_id = mock 'vm_id'
    client = stub_everything 'client' do
      stubs(:valid_credentials?).returns(true)
      expects(:status).with(vm_id).returns(:initializing)
    end
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything 'record' do
      stubs(:vm_id).returns(vm_id)
    end
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).returns(client)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :initializing, status
  end

  def test_resource_status_init_ssh
    vm_id = mock 'vm_id'
    client = stub_everything 'client' do
      stubs(:valid_credentials?).returns(true)
      expects(:status).with(vm_id).returns(:running)
    end
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything 'record' do
      stubs(:vm_id).returns(vm_id)
      stubs(:has_ssh_address?).returns(true)
    end
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).returns(client)
    facade.stubs(:shared_ssh_session).with(record).raises(Errno::ECONNREFUSED)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :initializing, status
  end

  def test_resource_status_ready_before_pid
    vm_id = mock 'vm_id'
    client = stub_everything 'client' do
      stubs(:valid_credentials?).returns(true)
      expects(:status).with(vm_id).returns(:running)
    end
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything 'record' do
      stubs(:vm_id).returns(vm_id)
      stubs(:has_ssh_address?).returns(true)
    end
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).returns(client)
    facade.stubs(:shared_ssh_session).with(record)
    facade.expects(:app_running?).never

    status = facade._simulation_manager_resource_status(record)

    assert_equal :ready, status
  end

  def test_resource_status_running_sm
    vm_id = mock 'vm_id'
    pid = mock 'pid'
    ssh = stub_everything 'ssh'
    client = stub_everything 'client' do
      stubs(:valid_credentials?).returns(true)
      expects(:status).with(vm_id).returns(:running)
    end
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything 'record' do
      stubs(:vm_id).returns(vm_id)
      stubs(:has_ssh_address?).returns(true)
      stubs(:pid).returns(pid)
    end
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).returns(client)
    facade.stubs(:shared_ssh_session).with(record).returns(ssh)
    facade.stubs(:app_running?).with(ssh, pid).returns(true)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :running_sm, status
  end

  def test_resource_status_ready_after_term
    vm_id = mock 'vm_id'
    pid = mock 'pid'
    ssh = stub_everything 'ssh'
    client = stub_everything 'client' do
      stubs(:valid_credentials?).returns(true)
      expects(:status).with(vm_id).returns(:running)
    end
    client_class = stub_everything 'client_class' do
      stubs(:new).returns(client)
    end
    record = stub_everything 'record' do
      stubs(:vm_id).returns(vm_id)
      stubs(:has_ssh_address?).returns(true)
      stubs(:pid).returns(pid)
    end
    facade = CloudFacade.new(client_class)
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:cloud_client_instance).returns(client)
    facade.stubs(:shared_ssh_session).with(record).returns(ssh)
    facade.stubs(:app_running?).with(ssh, pid).returns(false)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :ready, status
  end

  def test_start_simulation_managers
    user_id = mock 'user_id'
    experiment_id = mock 'experiment_id'
    image_secrets_id = mock 'image_secrets_id'
    time_limit = mock 'time_limit'
    start_at = mock 'start_at'
    instance_type = mock 'instance_type'
    instances_count = 3
    records = mock 'records' do
      stubs(:count).returns(instances_count)
    end


    # returns nil - image_secrets not used
    @facade.stubs(:get_and_validate_image_secrets).with(image_secrets_id, user_id)

    @facade.expects(:create_and_save_records)
      .with(instances_count, image_secrets_id, user_id, experiment_id, time_limit, start_at, instance_type)
      .returns(records)

    @facade.logger.expects(:error).never

    @facade.start_simulation_managers(user_id, instances_count, experiment_id,
                                      'image_secrets_id'=> image_secrets_id,
                                      'time_limit'=> time_limit,
                                      'start_at'=> start_at,
                                      'instance_type'=> instance_type)
  end

  # TODO: test get_and_validate_image_secrets

  def test_find_stored_params
    params = @facade.find_stored_params('stored_security_group' => 'quick', 'stored_test' => 'other')
    assert_includes params, 'security_group'
    assert_equal 'quick', params['security_group'], params
    assert_includes params, 'test'
    assert_equal 'other', params['test'], params
  end

end