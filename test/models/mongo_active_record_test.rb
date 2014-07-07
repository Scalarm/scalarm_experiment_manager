require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class MongoActiveRecordTest < MiniTest::Test

  class SomeRecord < MongoActiveRecord
  end

  def test_find_by_id_invalid
    # when, then
    result_nil = MongoActiveRecord.find_by_id(nil)
    result_string = MongoActiveRecord.find_by_id('bad_idea')
    result_all_nil = MongoActiveRecord.find_all_by_id(nil)
    result_all_string = MongoActiveRecord.find_all_by_id('worse_idea')

    assert_nil result_nil
    assert_nil result_string
    assert_nil result_all_nil
    assert_nil result_all_string
  end

  def test_mixed_attributes_new
    collection = mock do
      expects(:save).with('a'=>2, 'b'=>3)
    end

    SomeRecord.expects(:collection).returns(collection)
    r = SomeRecord.new({a: 1, 'a'=> 2, b: 3})
    r.save
  end

  def test_mixed_attributes_modify
    collection = mock do
      expects(:update).with({'_id'=>1}, {'_id'=>1, 'a'=>2}, {:upsert => true})
    end

    SomeRecord.expects(:collection).returns(collection)
    r = SomeRecord.new({'_id'=>1, a: 1})
    r.a = 2
    r.save

    assert_equal 2, r.a
  end

  def test_save_if_exists
    id = mock 'id'
    record = SomeRecord.new({id: id})
    record.stubs(:id).returns(id)
    SomeRecord.stubs(:find_by_id).with(id).returns(record)

    record.expects(:save).once

    record.save_if_exists
  end

  def test_save_if_exists_false
    id = mock 'id'
    record = SomeRecord.new({id: id})
    record.stubs(:id).returns(id)
    SomeRecord.stubs(:find_by_id).with(id).returns(nil)

    record.expects(:save).never

    record.save_if_exists
  end

end