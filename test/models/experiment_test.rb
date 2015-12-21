require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentTest < MiniTest::Test

  def setup
    @experiment = Experiment.new({})

    @experiment2 = Experiment.new({experiment_input:
                                      [{"id" => "main_category", "label" => "Main category", "entities" =>
                                          [{"id" => "main_group", "label" => "group Main", "parameters" =>
                                              [{"id" => "parameter1", "type" => "integer", "label" => "Param1",
                                                "min" => "1", "max" => "3", "step" => "1",
                                                "with_default_value" => false, "index" => 1,
                                                "parametrizationType" => "range", "in_doe" => true},
                                               {"id" => "parameter2", "type" => "integer",
                                                "min" => "1", "max" => "3", "step" => "1",
                                                "with_default_value" => false, "index" => 2,
                                                "parametrizationType" => "range", "in_doe" => false},
                                               {"id" => "parameter3", "type" => "integer",
                                               "min" => 1, "max" => 3, "value" => "2",
                                               "with_default_value" => false, "index" => 3,
                                               "parametrizationType" => "value", "in_doe" => false}]
                                           }]
                                       }
                                      ],
                                   doe_info: [
                                    ["2k", ["main_category___main_group___parameter1"], [[1], [3]]]
                                   ]
                                 })

    @experiment_with_flat_space = Experiment.new({experiment_input:
                                                      [{"entities"=>[
                                                          {"parameters"=>[
                                                              {"id"=>"param-0", "label"=>"New parameter 1",
                                                               "type"=>"integer", "min"=>"0", "max"=>"100",
                                                               "with_default_value"=>false, "index"=>1,
                                                               "parametrizationType"=>"range", "step"=>"20",
                                                               "in_doe"=>false},
                                                              {"id"=>"param-1", "label"=>"New parameter 2 ",
                                                               "type"=>"integer", "min"=>0, "max"=>100,
                                                               "with_default_value"=>false, "index"=>2,
                                                               "parametrizationType"=>"value", "value"=>"0",
                                                               "in_doe"=>false}]}]}],
                                                  doe_info: []
                                                 })
  end

  def test_add_to_shared
    experiment = Experiment.new({})
    user_id = mock 'user_id'
    experiment.expects(:shared_with=).with([user_id])

    experiment.add_to_shared(user_id)
  end

  def test_share_with_anonymous
    user_id = mock 'user_id'
    anonymous_user = mock 'anonymous_user' do
      stubs(:id).returns(user_id)
    end
    ScalarmUser.stubs(:get_anonymous_user).returns(anonymous_user)

    experiment = Experiment.new({})
    experiment.expects(:add_to_shared).with(user_id)

    experiment.share_with_anonymous
  end

  def test_double_share_with_anonymous
    user_id = mock 'user_id'
    anonymous_user = mock 'anonymous_user' do
      stubs(:id).returns(user_id)
    end
    ScalarmUser.stubs(:get_anonymous_user).returns(anonymous_user)

    experiment = Experiment.new({})
    experiment.expects(:add_to_shared).with(user_id).once

    experiment.stubs(:shared_with).returns(nil)
    experiment.share_with_anonymous
    experiment.stubs(:shared_with).returns([user_id])
    experiment.share_with_anonymous
  end

  def test_all_already_sent
    @experiment.stubs(:is_running).returns(true)
    @experiment.stubs(:experiment_size).returns(10)
    @experiment.stubs(:count_all_generated_simulations).returns(10)
    @experiment.stubs(:count_sent_simulations).returns(2)
    @experiment.stubs(:count_done_simulations).returns(8)

    refute @experiment.has_simulations_to_run?
  end

  def test_has_more_simulations
    @experiment.stubs(:is_running).returns(true)
    @experiment.stubs(:experiment_size).returns(11)
    @experiment.stubs(:count_all_generated_simulations).returns(11)
    @experiment.stubs(:count_sent_simulations).returns(2)
    @experiment.stubs(:count_done_simulations).returns(8)

    assert @experiment.has_simulations_to_run?
  end

  def test_end_not_running
    @experiment.stubs(:is_running).returns(false).once
    @experiment.stubs(:experiment_size).never
    @experiment.stubs(:count_all_generated_simulations).never
    @experiment.stubs(:count_sent_simulations).never
    @experiment.stubs(:count_done_simulations).never

    assert (@experiment.end?)
  end

  def test_end_all_done
    @experiment.stubs(:is_running).returns(true).once
    @experiment.stubs(:experiment_size).returns(10).once
    @experiment.stubs(:count_done_simulations).returns(10).once

    assert @experiment.end?
  end

  def test_end_not
    @experiment.stubs(:is_running).returns(true).once
    @experiment.stubs(:experiment_size).returns(10).once
    @experiment.stubs(:count_done_simulations).returns(5).once

    refute (@experiment.end?)
  end

  def test_replication_level
    @experiment.size = nil
    @experiment.replication_level = 5
    @experiment.parameter_constraints = nil
    @experiment.stubs(:value_list).returns([[1, 2, 3], [1, 2]])

    assert_equal 30, @experiment.experiment_size
  end

  def test_range_arguments_lookup
    assert_equal ["main_category___main_group___parameter1", "main_category___main_group___parameter2"],
                 @experiment2.range_arguments
  end

  def test_input_parameter_label_generation
    assert_equal "Main category - group Main - Param1" ,
                  @experiment2.input_parameter_label_for("main_category___main_group___parameter1")

    assert_equal "New parameter 1" ,
                  @experiment_with_flat_space.input_parameter_label_for("param-0")

  end

  def test_output_parameter_label_generation
    assert_equal "Throughput", Experiment.output_parameter_label_for("throughput")
    assert_equal "Storage throughput", Experiment.output_parameter_label_for("storage throughput")
    assert_equal "Network throughput", Experiment.output_parameter_label_for("network_throughput")
    assert_equal "Network Throughput", Experiment.output_parameter_label_for("networkThroughput")
    assert_equal "Network Throughput and storage", Experiment.output_parameter_label_for("networkThroughput_and_storage")
  end

  def test_results_reading
    sim1 = mock("object")
    sim1.stubs(:result).returns({ "param1" => 1, "param2" => 2 })
    sim1.stubs(:is_error).returns(false)
    sim2 = mock("object")
    sim2.stubs(:result).returns({ "error_param1" => 1, "error_param2" => 2 })
    sim2.stubs(:is_error).returns(true)

    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([sim1, sim2])

    assert_equal ["param1", "param2"], @experiment2.result_names
  end

  def test_getting_values_for_parameter
    @experiment_with_flat_space.stubs(:save)
    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([])

    assert_equal [1, 3], @experiment2.parameter_values_for("main_category___main_group___parameter1")
    assert_equal [0, 20, 40, 60, 80, 100], @experiment_with_flat_space.parameter_values_for("param-0")
    assert_equal [0], @experiment_with_flat_space.parameter_values_for("param-1")


    @experiment_with_flat_space.add_parameter_values("param-1", [1, 2])
    assert_equal [0, 1, 2], @experiment_with_flat_space.parameter_values_for("param-1")
  end

end