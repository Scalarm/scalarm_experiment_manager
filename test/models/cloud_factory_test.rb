require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class PlGridFactoryTest < MiniTest::Test

  def setup
  end

  def teardown
  end

  def self.create_test_get_facade(name)
    define_method "test_get_#{name}" do
      facade = CloudFacadeFactory.instance.get_facade(name)
      assert_equal name, facade.short_name
    end
  end

  create_test_get_facade 'amazon'
  create_test_get_facade 'pl_cloud'
  create_test_get_facade 'google'

end