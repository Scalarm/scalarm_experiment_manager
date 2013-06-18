require 'json'
require 'net/http'
require 'uri'

require 'fileutils'

require_relative 'experiment_manager'
require_relative 'storage_manager'

class IO
  def self.write(filename, text) 
    File.open(filename, 'a') do |file|
      file.puts(text)
    end
  end
end


# 1. load config file and create proxies
config = JSON.parse(IO.read('config.json'))
em_proxy = ExperimentManager.new(config)
sm_proxy = StorageManager.new(config)

# 2. check if an experiment id is specified and if there is no experiment id get one
#if not config.has_key?('experiment_id')
#  puts 'Getting experiment id'
#
#  while (experiment_id = em_proxy.get_experiment_id.to_i) == 0
#    sleep 30
#  end
#
#else
  experiment_id = config['experiment_id']
#end

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

while true
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

      # 6c.1. progress monitoring scheduling if available
      progress_monitor_pid = nil
      if File.exist?(File.join(code_base_dir, 'progress_monitor'))
        progress_monitor_pid = Process.fork do
          require 'json'
          sm_root_dir = File.join('.', '..', '..')

          puts "[progress_monitor] #{Dir.pwd}"
          config = JSON.parse(IO.read(File.join(sm_root_dir, 'config.json')))
          experiment_id = config['experiment_id']
          em_proxy = ExperimentManager.new(config)
          code_base_dir = File.absolute_path(File.join(sm_root_dir, "experiment_#{experiment_id}", 'code_base'))

          if File.exist?(File.join(code_base_dir, 'progress_monitor'))

            while true
              progress_monitor_output = %x[#{code_base_dir}/progress_monitor]
              puts "[progress monitor] script output: #{progress_monitor_output}"

              tmp_result_file = 'intermediate_result.json'
              tmp_result = if File.exists?(tmp_result_file)
                             puts 'Reading intermediate results from a file'
                             JSON.parse(IO.read(tmp_result_file))
                           else # mocking tmp result
                             JSON.parse({'status' => 'ok', 'results' => { 'intermediate_results' => rand(100) }}.to_json)
                           end

              if tmp_result['status'] == 'ok'
                puts "[progress monitor] Everything went well -> we will upload the following intermediate results: #{tmp_result['results']}"

                response = em_proxy.report_intermediate_result(experiment_id, simulation_input['simulation_id'], tmp_result['results'])

                puts "[progress monitor] We got the following response: #{response}"
              end

              sleep 30
            end

          else
            puts '[progress_monitor] There is no progress monitor script'
          end

        end
      end

      executor_output = %x[#{code_base_dir}/executor]
      puts "Executor output: #{executor_output}"
      # 6c.2. killing progress monitor process
      unless progress_monitor_pid.nil?
        Process.kill('INT', progress_monitor_pid)
      end
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
                          puts 'No file => an error occured'
                          JSON.parse({ 'status' => 'error', 'results' => { } }.to_json)
                        end

    if simulation_output['status'] == 'ok'
      puts "Everything went well -> we will upload the following results: #{simulation_output['results']}"

      response = em_proxy.mark_as_complete(experiment_id, simulation_input['simulation_id'], simulation_output['results'])

      puts "We got the following response: #{response}"
    end
    # upload binary_output if provided
    output_binary_file = "#{simulation_dir}/output.tar.gz"
    if File.exist?(output_binary_file)
      sm_proxy.upload_binary_output(experiment_id, simulation_input['simulation_id'], output_binary_file)
    end

    # 6f. go to the 6 point
  end

end

# 7. clean up the experiment
#FileUtils.rm_rf(experiment_dir)
