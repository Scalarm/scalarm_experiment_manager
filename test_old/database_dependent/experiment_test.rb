require 'csv'
require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'

class ExperimentTest < MiniTest::Test
  # TODO: this test uses database connection

  def setup
    i, @parameters, @parameter_values = 0, [], []

    CSV.foreach(File.join(__dir__, 'experiment_52f257042acf1465af000001.csv')) do |row|
      if i == 0
        @parameters = row
      else
        row_values = []
        row.each do |cell|
          begin
            parsed_cell = JSON.parse(cell)
            row_values << parsed_cell.map(&:to_f)
          rescue => e
            row_values << [ cell.to_f ]
          end
        end
        p = row_values[0]
        1.upto(row_values.size - 1).each do |i|
          p = p.product(row_values[i])
        end
        @parameter_values += p.map(&:flatten)
      end

      i += 1
    end

    @simulation = Simulation.new({ 'input_specification' => "[\n  {\n    \"id\": \"clustering\",\n    \"label\": \"Clustering\",\n\n    \"entities\": [\n      {\n        \"id\": \"phase_1\",\n        \"label\": \"Phase 1 - kdist\",\n        \"parameters\": [\n          {\n            \"id\": \"minpts\",\n            \"label\": \"Neighbourhood counter\",\n            \"type\": \"integer\",\n            \"min\": 250,\n            \"max\": 260\n          }\n        ]\n      }\n    ] \n  }\n]".to_json })

    Rails.configuration.experiment_seeks = {}

    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
  end


  def test_experiment_generation_from_csv
    experiment = Experiment.new({ 'doe_info' => [ [ 'csv_import', @parameters, @parameter_values ] ] })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)

    assert_equal 24206, experiment.experiment_size
    assert_equal 2, experiment.parameters.flatten.size
  end

  def test_file_with_ids_creation
    experiment = Experiment.new({ 'doe_info' => [ [ 'csv_import', @parameters, @parameter_values ] ], 'debug' => true })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)

    File.delete(experiment.file_with_ids_path) if File.exist?(experiment.file_with_ids_path)

    experiment.create_file_with_ids

    simulation_ids = []
    0.upto(experiment.experiment_size*2 - 1).each do |experiment_seek|
      next_simulation_id = IO.read(experiment.file_with_ids_path, 4, 4*experiment_seek)
      simulation_ids << next_simulation_id.unpack('i').first unless next_simulation_id.nil?
    end

    assert_equal 24206, simulation_ids.size

    1.upto(experiment.experiment_size).each do |sim_id|
      assert simulation_ids.include?(sim_id)
    end
  end

  def test_next_simulation_id_with_seek
    experiment = Experiment.new({ 'doe_info' => [ [ 'csv_import', @parameters, @parameter_values ] ], 'debug' => true })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)

    File.delete(experiment.file_with_ids_path) if File.exist?(experiment.file_with_ids_path)

    experiment.create_file_with_ids

    experiment.expects(:simulation_runs).at_least_once.returns(SimulationRun.for_experiment('1'))

    simulation_ids = []

    while not (simulation_id = experiment.next_simulation_id_with_seek).nil?
      simulation_ids << simulation_id
    end

    assert_equal 24206, simulation_ids.size

    1.upto(experiment.experiment_size).each do |sim_id|
      assert simulation_ids.include?(sim_id)
    end
  end

  def test_get_next_instance
    experiment = Experiment.new({
                                    'doe_info' => [ [ 'csv_import', @parameters, @parameter_values ] ],
                                    'scheduling_policy' => 'monte_carlo',
                                    'debug' => true
                                })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)

    File.delete(experiment.file_with_ids_path) if File.exist?(experiment.file_with_ids_path)

    experiment.expects(:simulation_runs).at_least_once.returns([])
    #experiment.expects(:save_simulation).at_least_once
    experiment.expects(:naive_partition_based_simulation_hash).returns(nil)

    simulation_ids = []

    while not (simulation_run = experiment.get_next_instance).nil?
      simulation_ids << simulation_run.index
    end

    assert_equal 24206, simulation_ids.size

    1.upto(experiment.experiment_size).each do |sim_id|
      assert simulation_ids.include?(sim_id)
    end
  end

  def test_get_next_instance_multi_threaded
    experiment = Experiment.new({
                                    'doe_info' => [ [ 'csv_import', @parameters, @parameter_values ] ],
                                    'scheduling_policy' => 'monte_carlo',
                                    'debug' => true
                                })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)

    File.delete(experiment.file_with_ids_path) if File.exist?(experiment.file_with_ids_path)

    experiment.expects(:simulation_runs).at_least_once.returns([])
    #experiment.expects(:save_simulation).at_least_once
    experiment.expects(:naive_partition_based_simulation_hash).at_least_once.returns(nil)

    simulation_ids = []
    threads = []

    8.times do
      threads << Thread.new do
        while not (simulation_run = experiment.get_next_instance).nil?
          simulation_ids << simulation_run['index']
        end
      end

      threads.each{|t| t.join}
    end

    assert_equal 24206, simulation_ids.size

    1.upto(experiment.experiment_size).each do |sim_id|
      assert simulation_ids.include?(sim_id)
    end
  end

  def test_naive_partition_based_simulation_hash
    Rails.logger.debug(MongoActiveRecord.get_collection('experiment_52f257042acf1465af000001').db.name)
    experiment_size = 24206
    # experiment_size = 1000

    experiment = Experiment.new({
                                    'doe_info' => [ [ 'csv_import', @parameters, @parameter_values[0...experiment_size] ] ],
                                    'scheduling_policy' => 'monte_carlo'
                                })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)
    experiment.save
    experiment.experiment_id = experiment.id
    experiment.save
    experiment.insert_initial_bar

    puts "Progress bar info #{experiment.basic_progress_bar_info.inspect}"
    puts "Last bar #{experiment.progress_bar_table.find({}).to_a.last.inspect}"

    simulation_ids = []

    i = 0
    while not (simulation_id = experiment.naive_partition_based_simulation_hash).nil?
      i += 1
      puts("#{Time.now} - Size: #{i}") if i % 100 == 0
      simulation_ids << simulation_id
      simulation_run = SimulationRun.new(index: simulation_id, to_sent: false)
      simulation_run.save
      experiment.progress_bar_update(simulation_id, 'done')
    end

    1.upto(experiment.experiment_size).each do |sim_id|
      assert simulation_ids.include?(sim_id), "#{sim_id} should be in the response ids"
    end

    assert_equal experiment_size, simulation_ids.size
  end

  def test_real_life_get_next_instance
    experiment = Experiment.new({
                                    'doe_info' => [['csv_import', @parameters, @parameter_values]],
                                    'scheduling_policy' => 'monte_carlo'
                                })
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)

    File.delete(experiment.file_with_ids_path) if File.exist?(experiment.file_with_ids_path)

    simulation_ids = []
    threads = []

    8.times do
      threads << Thread.new do
        while not (simulation_run = experiment.get_next_instance).nil?
          simulation_ids << simulation_run['index']
          Rails.logger.debug("#{Time.now} - #{simulation_ids.size}") if simulation_ids.size % 100 == 0
        end
      end

      threads.each{|t| t.join}
    end

    assert_equal 24206, simulation_ids.size

    1.upto(experiment.experiment_size).each do |sim_id|
      assert simulation_ids.include?(sim_id)
    end
  end

end