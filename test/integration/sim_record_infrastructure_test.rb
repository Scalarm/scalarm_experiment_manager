require 'test_helper'
require 'json'
require 'db_helper'

class SimRecordInfrastructureTest < ActionDispatch::IntegrationTest
  include DBHelper

  def test_sim_record_infrastructure_name
    rec_inf = DummyRecord.new(infrastructure: 'dummy1')
    rec_inf.save

    rec_wo = DummyRecord.new({})
    rec_wo.save

    rec_wo2 = DummyRecord.new({})
    rec_wo2.infrastructure = 'dummy2'
    rec_wo2.save

    assert_equal 'dummy1', rec_inf.reload.infrastructure
    assert_equal 'dummy', rec_wo.reload.infrastructure
    assert_equal 'dummy2', rec_wo2.reload.infrastructure
  end

  def test_cloud_records
    rec1 = CloudVmRecord.new(cloud_name: 'one')
    rec1.save

    rec2 = CloudVmRecord.new(cloud_name: 'two', infrastructure: 'three')
    rec2.save

    assert_equal 'one', rec1.reload.infrastructure
    assert_equal 'three', rec2.reload.infrastructure
  end

end
