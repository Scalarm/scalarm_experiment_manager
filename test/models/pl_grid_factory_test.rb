require 'test/unit'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class PlGridFactoryTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def self.create_test_get_facade(name)
    define_method "test_get_#{name}" do
      facade = PlGridFacadeFactory.instance.get_facade(name)
      assert_equal name, facade.short_name
    end
  end

  create_test_get_facade 'qsub'
  create_test_get_facade 'glite'

end