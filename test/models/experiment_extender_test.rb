require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentExtenderTest < MiniTest::Test

  def setup
    # it has 1 value of the first param and 50 values of the second param
    @experiment = Experiment.new({experiment_input:
                                      [{"id" => "main_category", "entities" =>
                                          [{"id" => "main_group", "parameters" =>
                                              [{"id" => "parameter1", "type" => "integer", "index" => 1,
                                                "min" => 0, "max" => 1000, "with_default_value" => false, "value" => "0",
                                                "parametrizationType" => "value",
                                                "in_doe" => false},
                                               {"id" => "parameter2", "type" => "integer", "index" => 2,
                                                "min" => "1", "max" => "3", "step" => "1",
                                                "with_default_value" => false,
                                                "parametrizationType" => "range",
                                                "in_doe" => false}]
                                           }]
                                       }]
                                 })

    @experiment_with_doe = Experiment.new({experiment_input:
                                               [{"id" => "main_category", "entities" =>
                                                   [{"id" => "main_group", "parameters" =>
                                                       [{"id" => "parameter1",
                                                         "type" => "integer",
                                                         "min" => 0,
                                                         "max" => 1000,
                                                         "with_default_value" => false,
                                                         "index" => 1,
                                                         "parametrizationType" => "range",
                                                         "value" => "0",
                                                         "in_doe" => true},
                                                        {"id" => "parameter2",
                                                         "type" => "integer",
                                                         "min" => "1",
                                                         "max" => "100",
                                                         "step" => "2",
                                                         "with_default_value" => false,
                                                         "index" => 2,
                                                         "parametrizationType" => "range",
                                                         "in_doe" => true}]
                                                    }]
                                                }
                                               ],
                                           doe_info: [
                                               ["2k", ["main_category___main_group___parameter1", "main_category___main_group___parameter2"],
                                                [[0.0, 1.0], [0.0, 100.0], [1000.0, 1.0], [1000.0, 100.0]]]]
                                          })

    # it has 1 value of the first param and 50 values of the second param
    @experiment2 = Experiment.new({experiment_input:
                                      [{"id" => "main_category", "entities" =>
                                          [{"id" => "main_group", "parameters" =>
                                              [{"id" => "parameter1",
                                                "type" => "integer",
                                                "min" => "1",
                                                "max" => "3",
                                                "step" => "1",
                                                "with_default_value" => false,
                                                "index" => 1,
                                                "parametrizationType" => "range",
                                                "in_doe" => false},
                                               {"id" => "parameter2",
                                                "type" => "integer",
                                                "min" => "1",
                                                "max" => "3",
                                                "step" => "1",
                                                "with_default_value" => false,
                                                "index" => 2,
                                                "parametrizationType" => "range",
                                                "in_doe" => false}]
                                           }]
                                       }
                                      ]
                                 })
  end

  def test_extend_with_single_value
    @experiment.stubs(:save)
    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([])

    original_size = @experiment.experiment_size

    @experiment.add_parameter_values("main_category___main_group___parameter2", [100])

    assert_equal original_size + 1, @experiment.experiment_size
    assert_equal [[0], [1, 2, 3, 100]], @experiment.value_list
    assert_equal [4, 1], @experiment.multiply_list

    original_size = @experiment.experiment_size

    @experiment.add_parameter_values("main_category___main_group___parameter1", [200])

    assert_equal original_size * 2, @experiment.experiment_size
    assert_equal [[0, 200], [1, 2, 3, 100]], @experiment.value_list
    assert_equal [4, 1], @experiment.multiply_list
  end

  def test_extend_with_multiple_values
    @experiment.stubs(:save)
    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([])

    original_size = @experiment.experiment_size

    @experiment.add_parameter_values("main_category___main_group___parameter2", [100, 200, 300])

    assert_equal original_size + 3, @experiment.experiment_size
    assert_equal [[0], [1, 2, 3, 100, 200, 300]], @experiment.value_list
    assert_equal [6, 1], @experiment.multiply_list

    original_size = @experiment.experiment_size

    @experiment.add_parameter_values("main_category___main_group___parameter1", [100, 200, 300])

    assert_equal original_size * 4, @experiment.experiment_size
    assert_equal [[0, 100, 200, 300], [1, 2, 3, 100, 200, 300]], @experiment.value_list
    assert_equal [6, 1], @experiment.multiply_list

  end

  def test_extend_experiment_with_doe
    @experiment_with_doe.stubs(:save)
    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([])

    original_size = @experiment_with_doe.experiment_size

    @experiment_with_doe.add_parameter_values("main_category___main_group___parameter1", [1])

    assert_equal original_size + 2, @experiment_with_doe.experiment_size

    doe_info = @experiment_with_doe.doe_info

    input_parameter_space = doe_info.first.last

    assert input_parameter_space.include?([1, 1.0])
    assert input_parameter_space.include?([1, 100.0])
  end

  def test_update_simulations_indices
    @experiment2.stubs(:save)
    simulation_run = mock('object')
    simulation_run.stubs(:index).returns(4)
    simulation_run.expects(:destroy)
    simulation_run.expects(:save)
    simulation_run.expects(:index=).with(5)
    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([simulation_run])

    @experiment2.add_parameter_values("main_category___main_group___parameter2", [4])
  end
end