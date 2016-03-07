require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'active_support/testing/declarative'

class SupervisedExperimentTest < MiniTest::Test
  extend ActiveSupport::Testing::Declarative

  def setup
    @experiment = SupervisedExperiment.new({})
  end

  test 'supervised experiment should not be ended until it is marked as completed' do
    @experiment.stubs(:experiment_size).returns(1)
    @experiment.stubs(:cont_done_simulations).returns(1)

    refute @experiment.end?
  end

  test 'supervised experiment should be ended if it is marked as completed' do
    @experiment.stubs(:experiment_size).returns(5)
    @experiment.stubs(:cont_done_simulations).returns(1)
    @experiment.mark_as_complete!({'some' => 'results'})

    assert @experiment.end?
  end

end
