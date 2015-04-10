require 'test_helper'
require 'json'
require 'supervised_experiment_helper'

class MarkAsCompleteSupervisedExperimentTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super
    @su = ScalarmUser.new(login: 'a')
    @su.save
    @sim = Simulation.new(
        name: 'test_sim',
        description: 'test',
        input_specification:
            [{"entities"=>
                  [{"parameters"=>
                        [{"id"=>"parameter1", "label"=>"A", "type"=>"float", "min"=>1, "max"=>100},
                         {"id"=>"parameter2", "label"=>"B", "type"=>"float", "min"=>1, "max"=>100}]}
                  ]}
            ],
        user_id: @su.id
    )
    @sim.save
  end

  def test_query
    # given
    ExperimentFactory.create_experiment(@su.id, @sim, one: 1).save
    ExperimentFactory.create_custom_points_experiment(@su.id, @sim, one: 1).save
    ExperimentFactory.create_supervised_experiment(@su.id, @sim, one: 1).save
    ExperimentFactory.create_supervised_experiment(@su.id, @sim, one: 2).save

    # when
    all_experiments = Experiment.where({})
    all_custom = CustomPointsExperiment.where({})
    all_supervised = SupervisedExperiment.where({})
    only_first = SupervisedExperiment.where(one: 1)

    # then
    assert_equal 4, all_experiments.count
    # FIXME will fail because supervised experiment is not valid custom point experiment
    #assert_equal 3, all_custom.count
    # FIXME will fail because supervised experiments have no valid custom points fields
    assert_equal 2, all_supervised.count
    assert_equal 1, only_first.count
  end

  def test_extend_custom_points
    se = ExperimentFactory.create_custom_points_experiment(@su.id, @sim)
    se.add_point! [1, 2]
    se.get_result_for(parameter1: 1, parameter2: 2)
  end

  def test_extend_supervised
    se = ExperimentFactory.create_supervised_experiment(@su.id, @sim)
    se.add_point! [1, 2]
    se.get_result_for(parameter1: 1, parameter2: 2)
  end

end
