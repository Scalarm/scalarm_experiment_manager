require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class MockDatabaseTest < MiniTest::Test

  def test_mock_collection
    # given
    collection = MockCollection.new([{id: 1, name: 'hello'}, {id: 2, name: 'hello'}, {id: 3, name: 'world'}])

    # when
    results_hello = collection.find({name: 'hello'})
    results_id2 = collection.find({id: 2})
    results_id1 = collection.find({id: 1, name: 'hello'})
    results_with_nil = collection.find({other: nil})

    # then
    assert_equal results_hello.count, 2
    assert results_hello.all? {|r| r[:name] == 'hello'}, results_hello.to_s

    assert_equal 1, results_id2.count
    assert_equal 2, results_id2[0][:id]

    assert_equal 1, results_id1.count
    assert_equal({id: 1, name: 'hello'}, results_id1[0])

    assert_equal 3, results_with_nil.count
  end

  def test_mock_record
    # given
    r1 = MockRecord.new({id: 1, name: 'hello'})
    r2 = MockRecord.new({id: 2, name: 'world'})

    r1.save
    r2.save

    # when
    hello_results = MockRecord.find_all_by_query({name: 'hello'})

    # then
    assert_equal 1, hello_results.count
    assert_equal 1, hello_results[0].attributes[:id]
    assert_equal 'hello', hello_results[0].attributes[:name]

  end

end