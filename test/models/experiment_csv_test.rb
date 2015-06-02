require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentCsvTest < MiniTest::Test

  def setup
    @experiment = Experiment.new({})

    @experiment.stubs(:parameters).returns(%w(x y))
    @experiment.stubs(:moe_names).returns(%w(one two))

    sim1 = mock 'sim1' do
      stubs(:index).returns(1)
      stubs(:values).returns('1.0,2')
      stubs(:result).returns({'one'=> 3, 'two' => 4})
    end

    sim2 = mock 'sim2' do
      stubs(:index).returns(2)
      stubs(:values).returns('2.0,3')
      stubs(:result).returns({'one'=> 4, 'two' => 5})
    end

    sim3 = mock 'sim3' do
      stubs(:index).returns(3)
      stubs(:values).returns('3.0,4')
      stubs(:result).returns({'one'=> 5, 'two' => 6})
    end

    simulation_runs = mock 'simulation_runs'
    simulation_runs.stubs(:where).returns([sim1, sim2, sim3])

    @experiment.stubs(:simulation_runs).returns(simulation_runs)
  end

  def test_convert_type
    assert_equal 1, ExperimentCsvImporter.convert_type('1')
    assert_equal 1.2, ExperimentCsvImporter.convert_type('1.2')
    assert_equal 'hello', ExperimentCsvImporter.convert_type('hello')

    assert ExperimentCsvImporter.convert_type('1').kind_of? Integer
    assert ExperimentCsvImporter.convert_type('1.0').kind_of? Float
    assert ExperimentCsvImporter.convert_type('hello').kind_of? String
  end

  def test_csv_full
    # given
    csv_should = <<-CSV
simulation_index,x,y,one,two
1,1.0,2,3,4
2,2.0,3,4,5
3,3.0,4,5,6
    CSV

    # when
    csv = @experiment.create_result_csv(true, true, true)

    # then
    assert_equal csv_should, csv
  end

  def test_csv_no_ids
    # given
    csv_should = <<-CSV
x,y,one,two
1.0,2,3,4
2.0,3,4,5
3.0,4,5,6
    CSV

    # when
    csv = @experiment.create_result_csv(false, true, true)

    # then
    assert_equal csv_should, csv
  end

  def test_csv_no_ids_no_moes
    # given
    csv_should = <<-CSV
x,y
1.0,2
2.0,3
3.0,4
    CSV

    # when
    csv = @experiment.create_result_csv(false, true, false)

    # then
    assert_equal csv_should, csv
  end

end