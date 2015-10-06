require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'

# CSV_FILE = 'experiment_52f257042acf1465af000001.csv'
# SIMULATIONS_COUNT = 24206

CSV_FILE = 'experiment_2.csv'
SIMULATIONS_COUNT = 9


class ExperimentIntegrationTest < MiniTest::Test
  # NOTICE: slow test
  include DBHelper

  # Given experiment is created as <<experiment_class>>
  #   with factory method <<factory_method>> (symbol)
  #   and we save it in database
  # When we get if from database using Experiment
  #   and we use class narrowing (auto_convert)
  # Then we should get the object of class <<experiment_class>>
  def self.define_convert_test(factory_method, experiment_class)
    define_method "test_auto_convert_to_#{experiment_class.name}" do
      # Given
      user_id = ScalarmUser.new(login: 'test').save.id
      simulation = Simulation.new({})
      simulation.input_specification = []
      simulation.save
      ExperimentFactory.send(factory_method, user_id, simulation, hello: 'world').save

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

end