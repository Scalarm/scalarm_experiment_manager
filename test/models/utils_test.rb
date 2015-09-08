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

  def test_header_newlines
    content_orig = 'hello\r\nworld'
    content_converted = "hello\nworld"

    assert_equal content_converted, Utils::header_newlines_deserialize(content_orig)
  end

  def test_parse_param_success_return
    params={}
    params[:hello]=1
    Utils::parse_param(params, :hello, lambda{|x| x+1})
    assert_equal 2, params[:hello]
  end

  def test_extract_type_from_string
    assert_equal "integer", Utils::extract_type_from_string("1")
    assert_equal "integer", Utils::extract_type_from_string("-1")
    assert_equal "float", Utils::extract_type_from_string("12.2")
    assert_equal "string", Utils::extract_type_from_string("loveRuby")
    assert_equal "string", Utils::extract_type_from_string("12.always")
    assert_equal "undefined", Utils::extract_type_from_string({id: 12})
  end

  def test_extract_type_from_value
    assert_equal "integer", Utils::extract_type_from_value(1)
    assert_equal "integer", Utils::extract_type_from_value(-1)
    assert_equal "float", Utils::extract_type_from_value(12.2)
    assert_equal "string", Utils::extract_type_from_value("loveRuby")
    assert_equal "string", Utils::extract_type_from_value("12.always")
    assert_equal "undefined", Utils::extract_type_from_value({id: 12})
  end

end