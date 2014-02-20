require 'test/unit'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentTest < Test::Unit::TestCase

  def setup
    @simulation = Simulation.new({ 'input_specification' => "[{\"id\": \"clustering\",\"label\": \"Clustering\",\"entities\": [\n      {\n        \"id\": \"phase_1\",\n        \"label\": \"Phase 1 - kdist\",\n        \"parameters\": [\n          {\n            \"id\": \"minpts\",\n            \"label\": \"Neighbourhood counter\",\n            \"type\": \"integer\",\n            \"min\": 250,\n            \"max\": 260\n          }\n        ]\n      }\n    ] \n  }\n]" })

    Rails.configuration.experiment_seeks = {}

    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end


  def test_valid_csv_file
  	importer = ExperimentCsvImporter.new(IO.read(File.join(__dir__, 'experiment_52f257042acf1465af000001.csv')))

    assert_equal 2, importer.parameters.size
    assert_equal 24206, importer.parameter_values.size
  end

  def test_invalid_csv_file
  	importer = ExperimentCsvImporter.new(IO.read(File.join(__dir__, 'experiment_52f257042acf1465af000001.csv')), 
  		['clustering___phase_1___minpts'])

    assert_equal 1, importer.parameters.size
    assert_equal 40, importer.parameter_values.size
  end 

  def test_valid_csv_file_multiple_values
  	importer = ExperimentCsvImporter.new(IO.read(File.join(__dir__, 'experiment_2.csv')), ['clustering___phase_4___eps'])

    assert_equal 1, importer.parameters.size
    assert_equal 6, importer.parameter_values.size
  end   
end