require 'mocha'
require 'minitest/autorun'
require 'test_helper'

require 'db_helper'

class DatabaseTest < MiniTest::Test
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  class SomeRecord < Scalarm::Database::MongoActiveRecord
    use_collection 'some_records'
  end

  def test_mixed_attrs
    # create and save
    rec = SomeRecord.new({a: 1, 'b' => 2})
    rec.save

    # get and check values
    rec = SomeRecord.all[0]
    assert_equal 1, rec.a
    assert_equal 2, rec.b

    # modify and save
    rec.a = 3
    rec.b = 4
    rec.save

    # get modified and check values
    rec = SomeRecord.all[0]
    assert_equal 3, rec.a
    assert_equal 4, rec.b

  end

  def test_count
    5.times { SomeRecord.new({}).save }
    assert_equal 5, SomeRecord.collection.count
  end

end