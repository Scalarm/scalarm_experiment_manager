require 'csv'
require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class MongoActiveRecordTest < Test::Unit::TestCase

  def setup
  end

  def test_find_by_id_invalid
    # given
    MongoActiveRecord.stubs(:collection_name).returns('test_record')

    # when, then
    assert_nothing_raised do
      result_nil = MongoActiveRecord.find_by_id(nil)
      result_string = MongoActiveRecord.find_by_id('bad_idea')

      assert_nil result_nil
      assert_nil result_string
    end
  end
  
end