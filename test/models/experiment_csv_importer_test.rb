require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentCsvTest < MiniTest::Test

  def test_convert_type
    assert_equal 1, ExperimentCsvImporter.convert_type('1')
    assert_equal 1.2, ExperimentCsvImporter.convert_type('1.2')
    assert_equal 'hello', ExperimentCsvImporter.convert_type('hello')

    assert ExperimentCsvImporter.convert_type('1').kind_of? Integer
    assert ExperimentCsvImporter.convert_type('1.0').kind_of? Float
    assert ExperimentCsvImporter.convert_type('hello').kind_of? String
  end

  def test_csv_parameters_count
    csv_content = <<-csv
one,two
1,11
2,12
3,13
    csv

    importer = ExperimentCsvImporter.new(csv_content)

    assert_equal 2, importer.parameters.size
    assert_equal 3, importer.parameter_values.size
  end

  def test_proper_types
    csv_content = <<-csv
int,float,string
1,1.1,one
2,1.2,two
3,1.3,three
    csv

    importer = ExperimentCsvImporter.new(csv_content)

    assert_kind_of Integer, importer.parameter_values[0][0]
    assert_kind_of Float, importer.parameter_values[0][1]
    assert_kind_of String, importer.parameter_values[0][2]
  end

end