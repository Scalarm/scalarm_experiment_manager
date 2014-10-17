require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class EncryptedMongoActiveRecordTest < MiniTest::Test

  class SomeRecord < EncryptedMongoActiveRecord
  end

  def test_exclude_secrets_to_h
    record = SomeRecord.new({})
    record.secret_password = 'password'
    record.login = 'login1'

    hashed = record.to_h

    assert_includes hashed.keys, 'login'
    assert_equal 'login1', hashed['login']
    refute_includes hashed.keys, 'secret_password'
    refute_includes hashed.keys, 'password'
  end

end