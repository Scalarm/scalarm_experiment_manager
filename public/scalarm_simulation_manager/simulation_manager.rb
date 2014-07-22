require 'time'
require 'json'
require 'net/http'
require 'uri'
require 'fileutils'

require_relative 'experiment_manager'
require_relative 'storage_manager'
require_relative 'information_service'

class IO
  def self.write(filename, text)
    File.open(filename, 'a') do |file|
      file.puts(text)
    end
  end
end


# 1. load config file and create proxies
config = JSON.parse(IO.read('config.json'))
information_service = InformationService.new(config)
executed_experiments = []

# the main, infinite loop which iterates over experiments (or just use one experiment)
while true

  em_url = information_service.get_experiment_managers.sample
  raise 'No Experiment manager URL available' if em_url.nil?
  em_proxy = ExperimentManager.new(em_url, config)

  sm_url = information_service.get_storage_managers.sample
  # raise 'No Storage manager URL available' if sm_url.nil?
  sm_proxy = sm_url.nil? ? nil : StorageManager.new(sm_url, config)

  # 2. check if an experiment id is specified and if there is no experiment id get one
  if not config.has_key?('experiment_id')
    puts 'Getting experiment id'

    while (experiment_id = em_proxy.get_experiment_id.to_s).empty?
      sleep 30
    end

    if executed_experiments.include?(experiment_id)
      sleep 10
      next
    else
      executed_experiments << experiment_id
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

    Dir.foreach(code_base_dir) do |filename|
      next if File.file?("#{code_base_dir}/#{filename}")
      File.chmod(0777, "#{code_base_dir}/#{filename}")
    end

    puts %x[chmod a+x #{code_base_dir}/*]
  end

  # 5. run the initialization script
  # TODO - currently there isn't any

  # 1a. if the 'start_at' option set -> wait for this moment to start
  sleep(5) while config.include?('start_at') and (Time.parse(config['start_at']) - Time.now > 0)

  # 6. main loop
  all_sent_threshold, error_threshold = 10

  while true
  # 6a. get information about next simulation to calculate and store it in input.json file
    simulation_input = {}

    5.times do
      simulation_input = em_proxy.next_simulation(experiment_id)
      puts "Text format of simulation_input: #{simulation_input}"

      begin
        simulation_input = JSON.parse(simulation_input)
        break
      rescue Exception => e
        puts "Exception occured: #{e}"
      end
    end


    if simulation_input.nil? or (not simulation_input.include?('status'))
      puts "Could not retrieve proper simulation input"

      return
    elsif simulation_input['status'] == 'all_sent'
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

        if File.exist?("#{code_base_dir}/input_writer")
          input_writer_output = %x[#{code_base_dir}/input_writer input.json]
          puts "Input writer output: #{input_writer_output}"
          IO.write('_stdout.txt', "Input writer output: #{input_writer_output}")
        end
      end

      # 6c. run an executor of this simulation
      Dir.chdir(simulation_dir) do |path|
        puts Dir.pwd

        # 6c.1. progress monitoring scheduling if available
        progress_monitor_pid = nil
        if File.exist?(File.join(code_base_dir, 'progress_monitor'))
          reader, writer = IO.pipe()

          progress_monitor_pid = Process.fork do
            require 'json'
            writer.close

            sm_root_dir = File.join('.', '..', '..')

            puts "[progress_monitor] #{Dir.pwd}"
            experiment_id = reader.gets.chop
            simulation_id = reader.gets.chop
            em_url = reader.gets.chop
            em_proxy = ExperimentManager.new(em_url, config)
            code_base_dir = File.absolute_path(File.join(sm_root_dir, "experiment_#{experiment_id}", 'code_base'))

            if File.exist?(File.join(code_base_dir, 'progress_monitor'))

              while true
                progress_monitor_output = %x[#{code_base_dir}/progress_monitor]
                puts "[progress monitor] script output: #{progress_monitor_output}"
                IO.write('_stdout.txt', "[progress monitor] script output: #{progress_monitor_output}")

                em_proxy.send_results_from('intermediate_result.json', true, experiment_id, simulation_id)

                sleep 30
              end

            else
              puts '[progress_monitor] There is no progress monitor script'
            end

          end

          reader.close
          writer.puts experiment_id
          writer.puts simulation_input['simulation_id']
          writer.puts em_url
        end

        executor_output = %x[#{code_base_dir}/executor]
        puts "Executor output: #{executor_output}"
        IO.write('_stdout.txt', "Executor output: #{executor_output}")
        # 6c.2. killing progress monitor process
        unless progress_monitor_pid.nil?
          puts "Killing the '#{progress_monitor_pid}' process"
          Process.kill('TERM', progress_monitor_pid)
          begin
            Timeout::timeout(15) do
              Process.wait(progress_monitor_pid)
            end
          rescue Timeout::Error
            puts "Waiting for child #{progress_monitor_pid} timeout"
          end
        end
      end

      # 6d. run an adapter script (output reader) to transform specific output format to scalarm model (output.json)
      Dir.chdir(simulation_dir) do |path|
        puts Dir.pwd

        if File.exist?("#{code_base_dir}/output_reader")
          output_reader_output = %x[#{code_base_dir}/output_reader]
          puts "Output reader output: #{output_reader_output}"
          IO.write('_stdout.txt', "Output reader output: #{output_reader_output}")
        end
      end

      # 6e. upload output json to experiment manager and set the run simulation as done
      em_proxy.send_results_from("#{simulation_dir}/output.json", false, experiment_id, simulation_input['simulation_id'])
      # upload binary_output if provided
      output_binary_file = "#{simulation_dir}/output.tar.gz"
      if File.exist?(output_binary_file) and not sm_proxy.nil?
        puts 'Uploading binary output'
        sm_proxy.upload_binary_output(experiment_id, simulation_input['simulation_id'], output_binary_file)
      end

      unless sm_proxy.nil?
        sm_proxy.upload_stdout(experiment_id, simulation_input['simulation_id'], File.join(simulation_dir, '_stdout.txt'))
      end

      # 6f. go to the 6 point
    end

  end

  break if config.has_key?('experiment_id')

end

# 7. clean up the experiment
#FileUtils.rm_rf(experiment_dir)
