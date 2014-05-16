require 'csv'
require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class CloudFacadeTest < Test::Unit::TestCase

  def setup
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

    cloud_name = 'c1'

    cloud_client = Object.new
    cloud_client.stubs(:short_name).returns('c1')
    cloud_client.stubs(:long_name).returns('Cloud One')

    CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user1_id})
      .returns([
        stub_record(user1_id, experiment1_id),
        stub_record(user1_id, experiment1_id),
        stub_record(user1_id, experiment2_id)
               ])

    CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user2_id})
    .returns([
                 stub_record(user2_id, experiment1_id),
                 stub_record(user2_id, experiment2_id)
             ])

    CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user1_id, experiment_id: nil})
      .returns(CloudVmRecord.find_all_by_query({cloud_name: cloud_name, user_id: user1_id}))

    CloudVmRecord.stubs(:find_all_by_query).with({cloud_name: cloud_name, user_id: user1_id, experiment_id: experiment1_id})
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

end