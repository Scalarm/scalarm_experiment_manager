require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class UtilsTest < MiniTest::Test

  def test_regexp_filename
    regexp = Utils::get_validation_regexp(:filename)

    assert regexp.match('hello')
    assert regexp.match('hello_world.py')
    assert regexp.match('hello-world.py')
    assert regexp.match('HelloWorld.py')
  end

end