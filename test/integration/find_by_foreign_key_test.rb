require 'test_helper'
require 'json'
require 'db_helper'

# Test an *ugly* hack allowing getting records querying by foreign key (*_id) which can be both string or BSON::ObjectId
class FindByForeignKeyTest < ActionDispatch::IntegrationTest
  include DBHelper

  def test_dummy_record_by_experiment_id
    exp = Experiment.new({})
    exp.save

    dr_bson = DummyRecord.new(experiment_id: exp.id, one: 'bson')
    dr_bson.save

    dr_str = DummyRecord.new(experiment_id: exp.id.to_s, one: 'str')
    dr_str.save

    bson_records_by_bson = DummyRecord.where(experiment_id: exp.id, one: 'bson')
    bson_records_by_str = DummyRecord.where(experiment_id: exp.id.to_s, one: 'bson')
    str_records_by_bson = DummyRecord.where(experiment_id: exp.id, one: 'str')
    str_records_by_str = DummyRecord.where(experiment_id: exp.id.to_s, one: 'str')

    assert_equal 1, bson_records_by_bson.count
    assert_equal 1, bson_records_by_str.count
    assert_equal 1, str_records_by_bson.count
    assert_equal 1, str_records_by_str.count
  end
end
