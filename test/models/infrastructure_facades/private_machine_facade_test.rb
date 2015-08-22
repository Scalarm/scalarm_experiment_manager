require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class PrivateMachineFacadeTest < MiniTest::Test

  def setup
    @facade = PrivateMachineFacade.new
    @facade.stubs(:logger).returns(stub_everything)
  end

  def stub_record(user_id, experiment_id)
    r = Object.new
    r.stubs(:user_id).returns(user_id)
    r.stubs(:experiment_id).returns(experiment_id)
    r
  end

  def test_get_infrastructure_sm_records
    # given
    user1_id = 1
    user2_id = 2

    experiment1_id = 'a'
    experiment2_id = 'b'

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user1_id})
    .returns([
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment2_id)
             ])

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user2_id})
    .returns([
                 stub_record(user2_id, experiment1_id),
                 stub_record(user2_id, experiment2_id)
             ])

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user1_id, experiment_id: nil})
    .returns(PrivateMachineRecord.find_all_by_query({user_id: user1_id}))

    PrivateMachineRecord.stubs(:find_all_by_query).with({user_id: user1_id, experiment_id: experiment1_id})
    .returns([
                 stub_record(user1_id, experiment1_id),
                 stub_record(user1_id, experiment1_id)
             ])


    facade = PrivateMachineFacade.new

    # when
    user1_records = facade.get_sm_records(user1_id)
    user1_exp1_records = facade.get_sm_records(user1_id, experiment1_id)

    # then
    assert_equal 3, user1_records.count
    assert user1_records.all? {|r| r.user_id == user1_id}

    assert_equal 2, user1_exp1_records.count
    assert user1_exp1_records.all? {|r| r.user_id == user1_id and r.experiment_id == experiment1_id}
  end

  def test_resource_status_not_avail
    record = stub_everything
    facade = PrivateMachineFacade.new
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session).raises(Errno::EHOSTUNREACH)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :not_available, status
  end

  def test_resource_status_avail
    record = stub_everything
    facade = PrivateMachineFacade.new
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session)
    facade.expects(:app_running?).never

    status = facade._simulation_manager_resource_status(record)

    assert_equal :available, status
  end

  def test_resource_status_running
    pid = mock 'pid'
    ssh = mock 'ssh'
    record = stub_everything do
      stubs(:pid).returns(pid)
    end
    facade = PrivateMachineFacade.new
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session).returns(ssh)
    facade.stubs(:app_running?).with(ssh, pid).returns(true)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :running_sm, status
  end

  def test_resource_status_released
    pid = mock 'pid'
    ssh = mock 'ssh'
    record = stub_everything do
      stubs(:pid).returns(pid)
    end
    facade = PrivateMachineFacade.new
    facade.stubs(:logger).returns(stub_everything)
    facade.stubs(:shared_ssh_session).returns(ssh)
    facade.stubs(:app_running?).with(ssh, pid).returns(false)

    status = facade._simulation_manager_resource_status(record)

    assert_equal :released, status
  end

  def test_get_credentials
    user_id = mock 'user_id'
    record = stub_everything 'record'
    records = [record]

    PrivateMachineCredentials.stubs(:where).with(user_id: user_id, host: 'localhost').returns(records)

    assert_equal records, @facade.get_credentials(user_id, host: 'localhost')
  end

  def test_prepare_resource_when_send_and_launch_success
    credentials = stub_everything 'credentials'
    ssh = stub_everything 'ssh'

    record = stub_everything 'record' do
      stubs(:onsite_monitoring).returns(false)
      stubs(:credentials).returns(credentials)
      expects(:store_error).never
    end

    InfrastructureFacade.stubs(:prepare_simulation_manager_package).yields

    PrivateMachineFacade.stubs(:sim_installation_retry_count).returns(0)

    @facade.stubs(:shared_ssh_session).with(credentials).once.returns(ssh)
    @facade.stubs(:log_exists?).returns(false)
    @facade.expects(:send_and_launch_sm).once.with(record, ssh).returns(100)

    assert_equal 100, @facade._simulation_manager_prepare_resource(record)
  end

  def test_prepare_resource_when_send_and_launch_failed
    credentials = stub_everything 'credentials'
    ssh = stub_everything 'ssh'

    record = stub_everything 'record' do
      stubs(:onsite_monitoring).returns(false)
      stubs(:credentials).returns(credentials)
      expects(:store_error).once do |a, _|
        a == 'install_failed'
      end
    end

    InfrastructureFacade.stubs(:prepare_simulation_manager_package).yields

    PrivateMachineFacade.stubs(:sim_installation_retry_count).returns(0)

    @facade.stubs(:shared_ssh_session).with(credentials).once.returns(ssh)
    @facade.stubs(:log_exists?).returns(false)
    @facade.expects(:send_and_launch_sm).once.with(record, ssh).returns(nil)

    @facade._simulation_manager_prepare_resource(record)
  end

  def test_prepare_resource_when_ssh_fails
    credentials = stub_everything 'credentials'
    ssh = stub_everything 'ssh'

    record = stub_everything 'record' do
      stubs(:onsite_monitoring).returns(false)
      stubs(:credentials).returns(credentials)
      expects(:store_error).once do |a, _|
        a == 'install_failed'
      end
    end

    InfrastructureFacade.stubs(:prepare_simulation_manager_package).yields
    PrivateMachineFacade.stubs(:sim_installation_retry_count).returns(0)

    @facade.stubs(:shared_ssh_session).with(credentials).once.raises(Errno::ECONNREFUSED)
    @facade.stubs(:log_exists?).never
    @facade.expects(:send_and_launch_sm).never

    assert_raises(Errno::ECONNREFUSED) do
      @facade._simulation_manager_prepare_resource(record)
    end
  end

  def test_prepare_resource_when_ssh_fails_mutiple_times
    credentials = stub_everything 'credentials'
    ssh = stub_everything 'ssh'

    record = stub_everything 'record' do
      stubs(:onsite_monitoring).returns(false)
      stubs(:credentials).returns(credentials)
      expects(:store_error).once do |a, _|
        a == 'install_failed'
      end
    end

    InfrastructureFacade.stubs(:prepare_simulation_manager_package).yields
    PrivateMachineFacade.stubs(:sim_installation_retry_count).returns(3)
    PrivateMachineFacade.stubs(:sim_installation_retry_delay).returns(1)

    @facade.stubs(:shared_ssh_session).with(credentials).times(3).raises(Errno::ECONNREFUSED)
    @facade.stubs(:log_exists?).never
    @facade.expects(:send_and_launch_sm).never

    assert_raises(Errno::ECONNREFUSED) do
      @facade._simulation_manager_prepare_resource(record)
    end
  end

end