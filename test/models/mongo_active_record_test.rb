require 'csv'
require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class MongoActiveRecordTest < Test::Unit::TestCase

  def setup
  end

  class MockCollection
    attr_accessor :records

    def initialize(records)
      @records = records
    end

    def find(attributes)
      records.select do |r|
        attributes.all? {|key, value| r[key] == value}
      end
    end
  end

  class TestRecord < MongoActiveRecord
    def self.collection

    end
  end

  def test_find_by_id_invalid
    # when, then
    assert_nothing_raised do
      result_nil = MongoActiveRecord.find_by_id(nil)
      result_string = MongoActiveRecord.find_by_id('bad_idea')
      result_all_nil = MongoActiveRecord.find_all_by_id(nil)
      result_all_string = MongoActiveRecord.find_all_by_id('worse_idea')

      assert_nil result_nil
      assert_nil result_string
      assert_nil result_all_nil
      assert_nil result_all_string
    end
  end

  def test_mock_collection
    # given
    collection = MockCollection.new([{id: 1, name: 'hello'}, {id: 2, name: 'hello'}, {id: 3, name: 'world'}])

    # when
    results_hello = collection.find({name: 'hello'})
    results_id2 = collection.find({id: 2})
    results_id1 = collection.find({id: 1, name: 'hello'})

    # then
    assert_equal results_hello.count, 2
    assert results_hello.all? {|r| r[:name] == 'hello'}, results_hello.to_s

    assert_equal results_id2.count, 1
    assert_equal results_id2[0][:id], 2

    assert_equal results_id1.count, 1
    assert_equal results_id1[0], {id: 1, name: 'hello'}
  end


end