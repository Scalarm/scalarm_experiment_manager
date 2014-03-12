class MonitoringProbe
  TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

  def initialize
    log('Starting')
    @config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))['monitoring']
    # TODO refactor
    begin
      @db_name = @config['db_name']
      @db = MongoActiveRecord.get_database(@db_name)
    rescue Exception => e
      log("Monitoring probe failed to start due to exception: #{e.to_s}")
      @db = nil
    end
    @interval = @config['interval'].to_i
    @metrics = @config['metrics'].split(':')

    @host = ""
    UDPSocket.open { |s| s.connect('64.233.187.99', 1); @host = s.addr.last }
    @host.gsub!("\.", "_")
  end

  def start_monitoring
    slog('monitoring_probe', "lock file exists? #{File.exists?(lock_file_path)}")
    Thread.new do

      slog('monitoring_probe', "lock file exists? #{File.exists?(lock_file_path)}")

      if File.exists?(lock_file_path)
        log('the lock file exists')
      else
        log('there is no lock file so we create one')
        IO.write(lock_file_path, Thread.current.object_id)

        at_exit{ File.delete(lock_file_path) if File.exist?(lock_file_path) }

        while true
          monitor
          sleep(60)
        end
      end

    end
  end

  def lock_file_path
    File.join Rails.root, 'tmp', 'em_monitoring.lock'
  end

  def log(message)
    Rails.logger.debug("[monitoring-probe][#{Thread.current.object_id}] #{message}")
  end

  def monitor
    measurements = @metrics.reduce([]) do |acc, metric_type|
      acc + self.send("monitor_#{metric_type}")
    end

    send_measurements(measurements)
  end

  def send_measurements(measurements)
    unless @db.nil?
      last_inserted_values = {}

      measurements.each do |measurement_table|
        table_name = "#{@host}.#{measurement_table[0]}"
        table = @db[table_name]

        last_value = nil
        if not last_inserted_values.has_key?(table_name) or last_inserted_values[table_name].nil?
          last_value = table.find_one({}, { :sort => [ [ "date", "desc" ] ]})
        else
          last_value = last_inserted_values[table_name]
        end

        doc = {"date" => measurement_table[1], "value" => measurement_table[2]}

        if not last_value.nil?

          last_date = last_value["date"]
          current_date = doc["date"]

          next if last_date > current_date
        end

        puts "Table: #{table_name}, Measurement of #{measurement_table[0]} : #{doc}"
        table.insert(doc)
        last_inserted_values[table_name] = doc
      end
    end
  end

  def send_measurement(controller, action, processing_time)
    unless @db.nil?
      table_name = "#{@host}.ExperimentManager___#{controller}___#{action}"
      doc = { date: Time.now, value: processing_time }
      @db[table_name].insert(doc)
    end
  end

  # monitors percantage utilization of the CPU [%]
  def monitor_cpu
    cpu_idle = if RUBY_PLATFORM.include?('darwin')
                 iostat_out = `iostat -c 3`
                 iostat_out = iostat_out.split("\n")[1..-1]
                 idle_index = iostat_out[0].split.index('id')
                 iostat_out[-1].split[idle_index].to_f
              else
                 mpstat_out = `mpstat 1 1`
                 mpstat_lines = mpstat_out.split("\n")
                 cpu_util_values = mpstat_lines[-1].split
                 cpu_util_values[-1].to_f
              end

    cpu_util = 100.0 - cpu_idle

    [ [ 'System___NULL___CPU', Time.now, cpu_util.to_i.to_s] ]
  end

  # monitoring free memory in the system [MB]
  def monitor_memory
    free_mem = if RUBY_PLATFORM.include?('darwin')
            mem_lines = `top -l 1 | head -n 10 | grep PhysMem`
            mem_line = mem_lines.split("\n")[0].split(',')[-1].split('unused').first.strip
            mem_line[0...-1]
          else
            mem_lines = `free -m`
            mem_line = mem_lines.split("\n")[1].split
            mem_line[3]
          end

    [ [ "System___NULL___Mem", Time.now, free_mem ] ]
  end
  
  ## monitors various metric related to block devices utilization
  def monitor_storage
    storage_measurements = {}
    # get 5 measurements of iostat - the first one is irrelevant
    iostat_out = `iostat -d -m -x 1 5`
    iostat_out_lines = iostat_out.split("\n")
    # analyze each line
    iostat_out_lines.each_with_index do |iostat_out_line, i|
      # line with Device at starts means new a new measurement
      if iostat_out_line.start_with?("Device:")
        storage_metric_names = iostat_out_line.split(" ")
        # get measurements for two first devices
        1.upto(2) do |k|
          if not iostat_out_lines[i+k].nil?
            storage_metric_values = iostat_out_lines[i+k].split(" ")
            device_name = storage_metric_values[storage_metric_names.index("Device:")]
            next if device_name.nil? || device_name.empty?
            puts "Device name -#{device_name}- -#{device_name.nil? || device_name.empty?}-"

            puts storage_metric_names.join(", ")
            ["rMB/s", "wMB/s", "r/s", "w/s", "await"].each do |system_storage_metric|
              storage_metric_name = "Storage___#{device_name}___#{system_storage_metric.gsub("/", "_")}"
              # insert metric measurement structure
              storage_measurements[storage_metric_name] = [] if not storage_measurements.has_key? storage_metric_name
              # insert metric measurement value
              storage_measurements[storage_metric_name] << storage_metric_values[storage_metric_names.index(system_storage_metric)]
            end
          end
        end
      end
    end

    storage_metrics = []
    # calculate avg values
    storage_measurements.each do |metric_name, measurements|
      puts measurements
      avg_value = measurements[1..-1].reduce(0.0){|sum, x| sum += x.to_f }
      avg_value /= measurements.size - 1
      storage_metrics << [metric_name, Time.now.strftime("%Y-%m-%d %H:%M:%S"), avg_value]
    end

    storage_metrics
  end

  #def monitor_experiment_manager
  #  log_dir = File.join(@config["installation_dir"], "scalarm_experiment_manager", "log")
  #  return [] if not File.exist?(log_dir)
  #
  #  measurements = []
  #  Dir.open(log_dir).each do |original_filename|
  #    filename = original_filename.split(".")[0]
  #    next if not original_filename.end_with?(".log") or filename.split("_") == 1 # not a log file
  #
  #    port = filename.split("_")[1]
  #    last_byte = @experiment_manager_log_last_bytes.has_key?(port) ? @experiment_manager_log_last_bytes[port] : 0
  #
  #    log_file = File.open(File.join(log_dir, original_filename), "r")
  #    log_file.seek(last_byte, IO::SEEK_SET)
  #
  #    request_measurements, bytes_counter = parse_manager_log_file(log_file.readlines, port)
  #    #measurements += calculate_avg_within_seconds(request_measurements)
  #    measurements += request_measurements
  #
  #    @experiment_manager_log_last_bytes[port] = last_byte + bytes_counter
  #  end
  #
  #  measurements
  #end
  #
  #private
  #
  #def parse_manager_log_file(new_lines, port)
  #  request_measurements, bytes_counter = [], 0
  #  is_request_parsing = false; request_method = ""; request_date = ""; temp_byte_counter = 0
  #
  #  new_lines.each do |log_line|
  #    temp_byte_counter += log_line.size
  #
  #    if not is_request_parsing and log_line.start_with?("Started")
  #      request_method = (log_line.split(" ")[2][2..-2]).split("/")[0..1].join("_").split("?")[0]
  #      request_date = log_line.split(" ")[-3] + " " + log_line.split(" ")[-2]
  #      is_request_parsing = true
  #    elsif is_request_parsing and log_line.start_with?("Completed")
  #      response_time = log_line.split(" ")[4]
  #
  #      is_request_parsing = false
  #
  #      if response_time.end_with?("ms")
  #        request_measurements << [ "ExperimentManager___#{port}___#{request_method}",
  #                                  request_date, response_time[0..-2].to_i ]
  #
  #        bytes_counter += temp_byte_counter
  #        temp_byte_counter = 0
  #        #puts "Date: #{request_date} --- Method: #{request_method} --- Response time: #{response_time}"
  #      end
  #    end
  #  end
  #
  #  return request_measurements, bytes_counter
  #end
  #
  #def calculate_avg_within_seconds(request_measurements)
  #  avg_request_measurements = {}
  #
  #  request_measurements.each do |method_name, tab_of_measurements|
  #    avg_measurements = {}
  #    tab_of_measurements.each do |time_and_value|
  #      avg_measurements[time_and_value[0]] = [] if not avg_measurements[time_and_value[0]]
  #      avg_measurements[time_and_value[0]] << time_and_value[1]
  #    end
  #
  #    avg_tab_of_measurements = []
  #    avg_measurements.each do |timestamp, measurements|
  #      measurement_sum = measurements.reduce(0) { |sum, element| sum += element.to_i }
  #      avg_tab_of_measurements << [Time.parse(timestamp), (measurement_sum/measurements.size).to_i]
  #    end
  #
  #    avg_request_measurements[method_name] = avg_tab_of_measurements.sort { |a, b| a[0] <=> b[0] }
  #
  #    puts "Method: #{method_name} --- Size: #{avg_tab_of_measurements.size} --- Measurements: #{avg_tab_of_measurements.join(",")}"
  #  end
  #
  #  avg_request_measurements
  #end

end
