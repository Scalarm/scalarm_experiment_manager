require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructureFacadeTest < MiniTest::Test

  def test_get_facade_for_fail
    assert_raises InfrastructureErrors::NoSuchInfrastructureError do
      InfrastructureFacadeFactory.get_facade_for('something_new')
    end

    assert_raises InfrastructureErrors::NoSuchInfrastructureError do
      InfrastructureFacadeFactory.get_facade_for(nil)
    end
  end


end