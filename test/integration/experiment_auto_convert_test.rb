require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'

class ExperimentAutoConvertTest < MiniTest::Test
  include DBHelper

  def create_experiment(factory_method)
    user_id = ScalarmUser.new(login: 'test').save.id
    simulation = Simulation.new({})
    simulation.input_specification = []
    simulation.save
    e = ExperimentFactory.send(factory_method, user_id, simulation, hello: 'world')
    e.save
    e
  end

  # Given experiment is created as <<experiment_class>>
  #   with factory method <<factory_method>> (symbol)
  #   and we save it in database
  # When we get if from database using Experiment
  #   and we use class narrowing (auto_convert)
  # Then we should get the object of class <<experiment_class>>
  def self.define_convert_test(factory_method, experiment_class)
    define_method "test_auto_convert_to_#{experiment_class.name}" do
      # Given
      create_experiment(factory_method)

      # When
      experiment = Experiment.find_by_hello('world')
      refute_nil experiment, 'Experiment fetched from database must not be nil'

      conv_experiment = experiment.auto_convert
      refute_nil conv_experiment, 'Converted experiment must not be nil'

      # Then
      assert_kind_of experiment_class, conv_experiment,
                     "Converted experiment should be of type #{experiment_class.name}"
    end
  end

  # Given experiment is created as custom points
  #   and we save it in database
  # When we get if from database using Experiment
  #   and we use class narrowing (auto_convert)
  # Then we should get the object of class CustomPointsExperiment
  define_convert_test(:create_custom_points_experiment, CustomPointsExperiment)

  # Given experiment is created as supervised
  #   and we save it in database
  # When we get if from database using Experiment
  #   and we use class narrowing (auto_convert)
  # Then we should get the object of class SupervisedExperiment
  define_convert_test(:create_supervised_experiment, SupervisedExperiment)

  # Given experiment is created as normal experiment
  #   and we save it in database
  # When we get if from database using Experiment
  #   and we use class narrowing (auto_convert)
  # Then we should get the object of class Experiment
  define_convert_test(:create_experiment, Experiment)

  ## Experiment find_by_* and where automatic conversions ##

  # Given
  #   A supervised is created and saved into database
  # When
  #   Experiment.where is used to get (single record, list) of experiments
  # Then
  #   We can get a single object with narrowed class
  def test_where_first_with_auto_convert
    # Given
    e = create_experiment(:create_supervised_experiment)
    e.name = 'some_name'
    e.save

    # When
    fetched_e = Experiment.where(name: 'some_name').first
    refute_nil fetched_e

    # Then
    assert_respond_to fetched_e, :mark_as_complete!,
                      'Fetched experiment should be of type SupervisedExperiment - so at least it should respond to mark_as_complete!'
  end

  # G: A supervised is created and saved into database
  # W: Experiment.where is used to get list of experiments
  # T: We can get a collection of objects with narrowed classes
  def test_where_with_auto_convert
    # Given
    e_normal = create_experiment(:create_experiment)
    e_normal.name = 'normal'
    e_normal.save

    e_custom = create_experiment(:create_custom_points_experiment)
    e_custom.name = 'custom_points'
    e_custom.save

    e_supervised = create_experiment(:create_supervised_experiment)
    e_supervised.name = 'supervised'
    e_supervised.save

    # When
    fetched_exps = Experiment.where({})
    refute_nil fetched_exps

    # Then
    normal_e = fetched_exps.where(name: 'normal').first
    refute_nil normal_e
    refute_respond_to normal_e, :add_point!

    custom_e = fetched_exps.where(name: 'custom_points').first
    refute_nil custom_e
    assert_respond_to custom_e, :add_point!

    supervised_e = fetched_exps.where(name: 'supervised').first
    refute_nil supervised_e
    assert_respond_to supervised_e, :mark_as_complete!
  end

end