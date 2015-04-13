require 'test_helper'
require 'json'
require 'db_helper'

class SimRecordInfrastructureTest < ActionDispatch::IntegrationTest
  include DBHelper

  def test_sim_record_infrastructure_name
    rec_inf = DummyRecord.new(infrastructure: 'dummy1')
    rec_inf.save

    rec_wo = DummyRecord.new({})
    rec_inf.save

    rec_wo2 = DummyRecord.new({})
    rec_wo2.infrastructure = 'dummy2'
    rec_wo2.save

    assert_equal 'dummy1', rec_inf.infrastructure
    assert_equal 'dummy', rec_wo.infrastructure
    assert_equal 'dummy2', rec_wo2.infrastructure
  end

  def test_cloud_records
    rec1 = CloudVmRecord.new(cloud_name: 'one')
    rec2 = CloudVmRecord.new(cloud_name: 'two', infrastructure: 'three')

    assert_equal 'one', rec1.infrastructure
    assert_equal 'three', rec2.infrastructure
  end

end
