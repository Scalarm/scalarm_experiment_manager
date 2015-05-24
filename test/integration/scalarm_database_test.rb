require 'test_helper'
require 'json'
require 'db_helper'

class ScalarmDatabaseTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  def test_model
    require 'scalarm/database'

    e = Scalarm::Database::Model::Experiment.new(a: 1)
    e.save

    assert_equal 1, Scalarm::Database::Model::Experiment.find_by_query(a: 1).a
  end

  def test_experiment
    require 'scalarm/database'

    e = Experiment.new(a: 2)
    e.save

    assert_equal 2, Scalarm::Database::Model::Experiment.find_by_query(a: 2).a
  end

end
