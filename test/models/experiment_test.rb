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

    @experiment_with_multiple_params = Experiment.new({experiment_input:
                                                           [{"entities" => [{"parameters" => [
                                                               {"id" => "param-0", "index" => 1, "parametrizationType" => "range",
                                                                "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                                "with_default_value" => false, "in_doe" => true},
                                                               {"id" => "param-1", "index" => 2, "parametrizationType" => "range",
                                                                "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                                "with_default_value" => false, "in_doe" => true},
                                                               {"id" => "param-2", "index" => 3, "parametrizationType" => "range",
                                                                "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                                "with_default_value" => false, "in_doe" => true},
                                                               {"id" => "param-3", "index" => 3, "parametrizationType" => "range",
                                                                "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                                "with_default_value" => false, "in_doe" => true},
                                                               {"id" => "param-4", "index" => 4, "parametrizationType" => "range",
                                                                "type" => "integer", "min" => "0", "max" => "100", "step" => "20",
                                                                "with_default_value" => false, "in_doe" => true}
                                                           ]}]}]
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

  def test_returning_correct_response_parameter_names
    sim1 = mock("object")
    sim1.stubs(:result).returns({ "param1" => 1, "param2" => 2 })
    sim1.stubs(:is_error).returns(false)
    sim2 = mock("object")
    sim2.stubs(:result).returns({ "error_param1" => 1, "error_param2" => 2 })
    sim2.stubs(:is_error).returns(true)

    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([sim1, sim2])


    simulation_response_names = @experiment2.result_names


    assert_equal ["param1", "param2"], simulation_response_names
  end

  def test_getting_values_for_parameter_in_experiment_with_structured_input_specification
    assert_equal [1, 3], @experiment2.parameter_values_for("main_category___main_group___parameter1")
  end

  def test_getting_values_for_parameter_in_experiment_with_flat_input_specification
    assert_equal [0, 20, 40, 60, 80, 100], @experiment_with_flat_space.parameter_values_for("param-0")
    assert_equal [0], @experiment_with_flat_space.parameter_values_for("param-1")
  end

  def test_getting_values_for_parameter_after_input_space_extension
    @experiment_with_flat_space.stubs(:save)
    Scalarm::Database::MongoActiveRecord.stubs(:where).returns([])

    @experiment_with_flat_space.add_parameter_values("param-1", [1, 2])

    assert_equal [0, 1, 2], @experiment_with_flat_space.parameter_values_for("param-1")
  end

  def test_doe_2k_method_should_return_low_and_high_levels_for_single_parameter
    @experiment_with_flat_space.doe_info = [["2k", ["param-0"]]]

    assert_equal [["2k", ["param-0"], [[0.0], [100.0]]]], @experiment_with_flat_space.apply_doe_methods
  end

  def test_doe_2k_method_should_return_combinations_of_low_and_high_levels_of_each_parameters
    @experiment_with_flat_space.doe_info = [["2k", ["param-0", "param-1"]]]

    assert_equal [["2k", ["param-0", "param-1"], [[0.0, 0.0], [0.0, 100.0], [100.0, 0.0], [100.0, 100.0]]]],
                 @experiment_with_flat_space.apply_doe_methods
  end

  def test_doe_fullFactorial_method_should_return_all_possible_values_of_single_parameter
    @experiment_with_flat_space.doe_info = [["fullFactorial", ["param-0"]]]

    assert_equal [["fullFactorial", ["param-0"], (0..100).step(20).map{|x| [x.to_f]}]],
        @experiment_with_flat_space.apply_doe_methods
  end

  def test_doe_fullFactorial_method_should_return_combinations_of_all_possible_values_of_every_parameter
    @experiment_with_multiple_params.doe_info = [["fullFactorial", ["param-0", "param-1"]]]

    generated_configurations = @experiment_with_multiple_params.apply_doe_methods

    assert_equal [["fullFactorial", ["param-0", "param-1"], (0..100).step(20).map{|x|
      [x.to_f]}.product((0..100).step(20).map{|x| [x.to_f]}).map(&:flatten)]],
        generated_configurations
  end

  def test_doe_2k_1_method_should_raise_error_when_too_few_parameters
    @experiment_with_multiple_params.doe_info = [["2k-1", ["param-0", "param-1"]]]

    err = assert_raises StandardError do
      @experiment_with_multiple_params.apply_doe_methods
    end

    assert_equal "Selected DoE method requires more than 2 parameters.", err.message
  end


  def test_doe_2k_1_method_should_return_half_of_full_factorial_balanced_configurations
    @experiment_with_multiple_params.doe_info = [["2k-1", ["param-0", "param-1", "param-2", "param-3", "param-4"]]]


    doe_method_result = @experiment_with_multiple_params.apply_doe_methods.first


    assert_equal "2k-1", doe_method_result[0]
    assert_equal ["param-0", "param-1", "param-2", "param-3", "param-4"], doe_method_result[1]
    assert_equal 16, doe_method_result[2].size

    # low and high levels should be balanced
    low_level_counters = [0, 0, 0, 0, 0]
    high_level_counters = [0, 0, 0, 0, 0]

    doe_method_result[2].each do |input_parameter_space_point|
      input_parameter_space_point.each_with_index do |value, index|
        if value > 0.0
          high_level_counters[index] += 1
        else
          low_level_counters[index] += 1
        end
      end
    end

    low_level_counters.each{|counter| assert_equal 8, counter}
    high_level_counters.each{|counter| assert_equal 8, counter}
  end

  def test_doe_2k_2_method_should_raise_error_when_too_few_parameters
    @experiment_with_multiple_params.doe_info = [["2k-2", ["param-0", "param-1"]]]

    err = assert_raises StandardError do
      @experiment_with_multiple_params.apply_doe_methods
    end

    assert_equal "Selected DoE method requires more than 4 parameters.", err.message
  end

  def test_doe_2k_2_method_should_return_quarter_of_full_factorial_balanced_configurations
    @experiment_with_multiple_params.doe_info = [["2k-2", ["param-0", "param-1", "param-2", "param-3", "param-4"]]]


    doe_method_result = @experiment_with_multiple_params.apply_doe_methods.first


    assert_equal "2k-2", doe_method_result[0]
    assert_equal ["param-0", "param-1", "param-2", "param-3", "param-4"], doe_method_result[1]
    assert_equal 8, doe_method_result[2].size

    low_level_counters = [0, 0, 0, 0, 0]
    high_level_counters = [0, 0, 0, 0, 0]

    doe_method_result[2].each do |input_parameter_space_point|
      input_parameter_space_point.each_with_index do |value, index|
        if value > 0.0
          high_level_counters[index] += 1
        else
          low_level_counters[index] += 1
        end
      end
    end

    low_level_counters.each{|counter| assert_equal 4, counter}
    high_level_counters.each{|counter| assert_equal 4, counter}
  end

  def test_doe_latin_hypercube_method_should_raise_error_when_too_few_parameters
    @experiment_with_multiple_params.doe_info = [["latinHypercube", ["param-0"]]]

    err = assert_raises StandardError do
      @experiment_with_multiple_params.apply_doe_methods
    end

    assert_equal "Selected DoE method requires more than 1 parameter.", err.message
  end

  # NOTE: if this test fails, install R "lhs" package in R interpreter with:
  # install.packages("lhs")
  def test_doe_latin_hypercube_method_should_return_evenly_distributed_points_across_parameter_space_2_param_case
    @experiment_with_multiple_params.doe_info = [["latinHypercube", ["param-0", "param-1"]]]


    doe_method_result = @experiment_with_multiple_params.apply_doe_methods.first


    assert_equal "latinHypercube", doe_method_result[0]
    assert_equal ["param-0", "param-1"], doe_method_result[1]
    assert_equal 6, doe_method_result[2].size

    level_counters = [ [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0] ]

    doe_method_result[2].each do |input_parameter_space_point|
      input_parameter_space_point.each_with_index do |value, index|
        level_counters[index][value / 20] += 1
      end
    end

    level_counters.each{|counter| assert_equal [1, 1, 1, 1, 1, 1], counter}
  end

  # NOTE: if this test fails, install R "lhs" package in R interpreter with:
  # install.packages("lhs")
  def test_doe_latin_hypercube_method_should_return_evenly_distributed_points_across_parameter_space_5_param_case
    @experiment_with_multiple_params.doe_info = [["latinHypercube", ["param-0", "param-1", "param-2", "param-3", "param-4"]]]


    doe_method_result = @experiment_with_multiple_params.apply_doe_methods.first



    assert_equal "latinHypercube", doe_method_result[0]
    assert_equal ["param-0", "param-1", "param-2", "param-3", "param-4"], doe_method_result[1]
    assert_equal 6, doe_method_result[2].size

    level_counters = [[0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0]]

    doe_method_result[2].each do |input_parameter_space_point|
      input_parameter_space_point.each_with_index do |value, index|
        level_counters[index][value / 20] += 1
      end
    end

    level_counters.each { |counter| assert_equal [1, 1, 1, 1, 1, 1], counter }
  end

  def test_gauss_dist_should_constantly_generate_1_value_between_max_and_min_with_string_type_arguments
    @experiment.stubs(:save)

    @experiment.experiment_input = [{"entities" => [
        {"parameters" => [
            {"id" => "param-0",
             "type" => "float", "min" => "0", "max" => "1",
             "with_default_value" => false, "index" => 1,
             "parametrizationType" => "gauss", "mean" => "0.5", "variance" => "0.1",
             "in_doe" => false}
        ]}
    ]}]

    1.upto(10) do
      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 1, param_values.size

      assert param_values.first >= 0.0
      assert param_values.first <= 1.0

      @experiment.clear_cached_data
    end
  end

  def test_gauss_dist_should_constantly_generate_1_value_between_max_and_min_with_float_type_arguments
    @experiment.stubs(:save)
    @experiment.experiment_input = [{"entities" => [
        {"parameters" => [
            {"id" => "param-0",
             "type" => "float", "min" => "0", "max" => "1",
             "with_default_value" => false, "index" => 1,
             "parametrizationType" => "gauss", "mean" => 0.5, "variance" => 0.1,
             "in_doe" => false}
        ]}
    ]}]

    1.upto(10) do
      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 1, param_values.size

      assert param_values.first >= 0.0
      assert param_values.first <= 1.0
      @experiment.clear_cached_data
    end

  end

  def test_gauss_dist_should_constantly_generate_1_value_between_max_and_min_with_integer_type_arguments
    @experiment.stubs(:save)
    @experiment.experiment_input = [{"entities" => [
        {"parameters" => [
            {"id" => "param-0",
             "type" => "integer", "min" => "0", "max" => "10",
             "with_default_value" => false, "index" => 1,
             "parametrizationType" => "gauss", "mean" => 5, "variance" => 1,
             "in_doe" => false}
        ]}
    ]}]

    1.upto(10) do
      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 1, param_values.size

      assert param_values.first >= 0
      assert param_values.first <= 10
      @experiment.clear_cached_data
    end
  end

  def test_uniform_dist_should_constantly_generate_1_value_between_max_and_min_with_string_type_arguments
    @experiment.stubs(:save)

    @experiment.experiment_input = [{"entities" => [
        {"parameters" => [
            {"id" => "param-0",
             "type" => "float", "min" => "0", "max" => "1",
             "with_default_value" => false, "index" => 1,
             "parametrizationType" => "uniform",
             "in_doe" => false}
        ]}
    ]}]

    1.upto(10) do
      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 1, param_values.size

      assert param_values.first >= 0.0
      assert param_values.first <= 1.0

      @experiment.clear_cached_data
    end
  end

  def test_uniform_dist_should_constantly_generate_1_value_between_max_and_min_with_float_type_arguments
    @experiment.stubs(:save)
    @experiment.experiment_input = [{"entities" => [
        {"parameters" => [
            {"id" => "param-0",
             "type" => "float", "min" => 0, "max" => 1,
             "with_default_value" => false, "index" => 1,
             "parametrizationType" => "uniform",
             "in_doe" => false}
        ]}
    ]}]

    1.upto(10) do
      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 1, param_values.size

      assert param_values.first >= 0.0
      assert param_values.first <= 1.0
      @experiment.clear_cached_data
    end
  end

  def test_uniform_dist_should_constantly_generate_1_value_between_max_and_min_with_integer_type_arguments
    @experiment.stubs(:save)
    @experiment.experiment_input = [{"entities" => [
        {"parameters" => [
            {"id" => "param-0",
             "type" => "integer", "min" => 0, "max" => 10,
             "with_default_value" => false, "index" => 1,
             "parametrizationType" => "uniform",
             "in_doe" => false}
        ]}
    ]}]

    1.upto(10) do
      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 1, param_values.size

      assert param_values.first >= 0
      assert param_values.first <= 10
      @experiment.clear_cached_data
    end
  end

  def test_custom_parametrization_should_return_values_stored_in_custom_values
      @experiment.stubs(:save)
      @experiment.experiment_input = [{"entities" => [
          {"parameters" => [
              {"id" => "param-0",
               "type" => "float", "min" => "0", "max" => "1",
               "with_default_value" => false, "index" => 1,
               "parametrizationType" => "custom",
               "custom_values" => [ 0.2, 0.7 ],
               "in_doe" => false}
          ]}
      ]}]


      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 2, param_values.size

      assert_equal [ 0.2, 0.7 ], param_values
  end

  def test_custom_parametrization_should_return_values_stored_in_custom_values_even_with_strings
      @experiment.stubs(:save)
      @experiment.experiment_input = [{"entities" => [
          {"parameters" => [
              {"id" => "param-0",
               "type" => "string",
               "with_default_value" => false, "index" => 1,
               "parametrizationType" => "custom",
               "custom_values" => [ "a", "b" ],
               "in_doe" => false}
          ]}
      ]}]


      generated_values = @experiment.value_list
      assert_equal 1, generated_values.size

      param_values = generated_values.first
      assert_equal 2, param_values.size

      assert_equal [ "a", "b" ], param_values
  end

  def test_generate_parameter_values_should_compute_valid_range_with_high_precision_step_in_reasonable_time
    require 'timeout'
    min = 1e-13
    max = 2e-13
    step = 1e-14
    experiment1 = Experiment.new({})

    parameter_values = Timeout.timeout 10 do
      experiment1.send(:generate_parameter_values, {
                     'parametrizationType' => 'range',
                     'label' => 'test_param',
                     'type' => 'float',
                     'step' => step,
                     'min' => min,
                     'max' => max
      })
    end

    assert_equal 10, parameter_values.count

    assert_equal 0.00000000000010, parameter_values[0]
    assert_equal 0.00000000000011, parameter_values[1]
    assert_equal 0.00000000000012, parameter_values[2]
    assert_equal 0.00000000000013, parameter_values[3]
    assert_equal 0.00000000000014, parameter_values[4]
    assert_equal 0.00000000000015, parameter_values[5]
    assert_equal 0.00000000000016, parameter_values[6]
    assert_equal 0.00000000000017, parameter_values[7]
    assert_equal 0.00000000000018, parameter_values[8]
    assert_equal 0.00000000000019, parameter_values[9]
  end
end
