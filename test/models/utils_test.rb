require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class UtilsTest < MiniTest::Test

  def test_regexp_filename
    regexp = Utils::get_validation_regexp(:filename)

    assert regexp, 'hello'
    assert regexp, 'hello_world.py'
    assert regexp, 'hello-world.py'
    assert regexp, 'HelloWorld.py'
  end

  def test_regexp_default
    regexp = Utils::get_validation_regexp(:default)

    assert regexp, 'hello_wo-rld'
  end

  def test_regexp_openid_id
    regexp = Utils::get_validation_regexp(:openid_id)

    openid_id = 'https://openid.plgrid.pl/plguser'

    assert_match regexp, openid_id
  end

  def test_regexp_json
    regexp = Utils::get_validation_regexp(:json)

    json_object = {one: :two, three: [{some: 1}, 2, 3]}.to_json

    assert_match regexp, json_object
  end

end