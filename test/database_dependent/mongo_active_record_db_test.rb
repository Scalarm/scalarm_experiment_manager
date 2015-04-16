require 'test_helper'
require 'db_helper'

class MongoActiveRecordDBTest < ActiveSupport::TestCase
  include DBHelper

  TEXT = 'text'
  OTHER_TEXT = 'text'

  test "proper behaviour of reload method" do
    e = Experiment.new({})
    e.test = TEXT
    e.save
    e.test = OTHER_TEXT
    e.reload
    assert_equal e.test, TEXT
  end

  test "proper behaviour of reload method 2" do
    e = Experiment.new({})
    e.test = TEXT
    e.save

    e2 = Experiment.first
    e2.test = OTHER_TEXT
    e2.save

    e.reload
    assert_equal e.test, OTHER_TEXT
  end
end