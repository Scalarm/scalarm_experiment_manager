require 'json'
require 'net/http'
require 'uri'

require 'fileutils'

require './experiment_manager.rb'

class IO
  def self.write(filename, text) 
    File.open(filename, 'a') do |file|
      file.puts(text)
    end
  end
end


# 1. load config file
config = JSON.parse(IO.read('config.json'))
puts config

em_proxy = ExperimentManager.new(config)

# 2. check if an experiment id is specified and if there is no experiment id get one
if not config.has_key?('experiment_id')
  puts 'Getting experiment id'

  while (experiment_id = em_proxy.get_experiment_id.to_i) == 0
    sleep 30
  end

else
  experiment_id = config['experiment_id']
end

puts "We will execute simulations from an experiment with ID #{experiment_id}"
experiment_dir = "experiment_#{experiment_id}"
Dir.mkdir(experiment_dir) if not File.exist?(experiment_dir)

# 3. get repository for the experiment
code_base_dir = File.absolute_path "./#{experiment_dir}/code_base"
if not File.exist?(code_base_dir)
  IO.write("#{code_base_dir}.zip", em_proxy.code_base(experiment_id))

  # 4. unzip the repository
  puts %x[unzip -d #{code_base_dir} #{code_base_dir}.zip; unzip -d #{code_base_dir} #{code_base_dir}/simulation_binaries.zip]
  Dir.foreach(code_base_dir){|filename| next if File.file?("#{code_base_dir}/#{filename}"); File.chmod(0777, "#{code_base_dir}/#{filename}")}
  puts %x[chmod a+x #{code_base_dir}/*]
end

# 5. run the initialization script
# TODO - currently there isn't any

# 6. main loop
all_sent_threshold, error_threshold = 10
#i = 1
while true
  #i = 2
# 6a. get information about next simulation to calculate and store it in input.json file
  simulation_input = em_proxy.next_simulation(experiment_id)
  puts "Text format of simulation_input: #{simulation_input}"
  simulation_input = JSON.parse(simulation_input)

  if simulation_input['status'] == 'all_sent'
    puts 'There is no more simulations to run in this experiment'
    break if all_sent_threshold <= 0
    all_sent_threshold -= 1

  elsif simulation_input['status'] == 'error'
    puts "An error occurred while getting next simulation: #{simulation_input['reason']}"

    break if error_threshold <= 0
    error_threshold -= 1

  elsif simulation_input['status'] == 'ok'
    puts "Our next simulation has an id: #{simulation_input['simulation_id']}"
    puts "It has the following execution constraints: #{simulation_input['execution_constraints']}"

    simulation_dir = File.absolute_path "./#{experiment_dir}/simulation_#{simulation_input['simulation_id']}"
    Dir.mkdir(simulation_dir)

    IO.write("#{simulation_dir}/input.json", simulation_input['input_parameters'].to_json)
    # 6b. run an adapter script (input writer) for input information: input.json -> some specific code
    Dir.chdir(simulation_dir) do |path|
      puts Dir.pwd

      input_writer_output = %x[#{code_base_dir}/input_writer input.json]
      puts "Input writer output: #{input_writer_output}"
    end

    # 6c. run an executor of this simulation
    Dir.chdir(simulation_dir) do |path|
      puts Dir.pwd

      executor_output = %x[#{code_base_dir}/executor]
      puts "Executor output: #{executor_output}"
    end

    # 6d. run an adapter script (output reader) to transform specific output format to scalarm model (output.json)
    Dir.chdir(simulation_dir) do |path|
      puts Dir.pwd

      output_reader_output = %x[#{code_base_dir}/output_reader]
      puts "Output reader output: #{output_reader_output}"
    end

    # 6e. upload output json to experiment manager and set the run simulation as done
    output_file = "#{simulation_dir}/output.json"
    simulation_output = if File.exists?(output_file)
                          puts 'Reading simulation output from a file'
                          JSON.parse(IO.read(output_file))
                        else
                          puts 'Mocking simulation response'
                          JSON.parse({ 'status' => 'ok', 'results' => { 'avg_error' => 6.2 } }.to_json)
                        end

    if simulation_output['status'] == 'ok'
      puts "Everything went well -> we will upload the following results: #{simulation_output['results']}"

      response = em_proxy.mark_as_complete(experiment_id, simulation_input['simulation_id'], simulation_output['results'])

      puts "We got the following response: #{response}"
    end
    # 6f. go to the 6 point
  end

end

# 7. clean up the experiment
#FileUtils.rm_rf(experiment_dir)
