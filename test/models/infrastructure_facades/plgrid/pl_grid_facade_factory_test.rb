require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class PlGridFacadeFactoryTest < MiniTest::Test

  def self.create_test_get_facade(name)
    define_method "test_get_#{name}" do
      facade = PlGridFacadeFactory.instance.get_facade(name)
      assert_equal name, facade.short_name
    end
  end

  create_test_get_facade 'qsub'
  # gLite is not used anymore (for now)
  # create_test_get_facade 'glite'
  create_test_get_facade 'qcg'

end