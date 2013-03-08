require 'yaml'
require 'net/http'

#require_relative "app/models/experiment_manager"

# utilities functions
class ScalarmExperimentManager

  def initialize
    @config = YAML::load_file File.join(".", "config", "scalarm_experiment_manager.yml")
    @host = ""
    UDPSocket.open { |s| s.connect('64.233.187.99', 1); @host = s.addr.last }
  end

  def start_server(starting_port, cluster_size)
    puts "Starting db router - cd #{@config["storage_manager_path"]}; ruby scalarm_storage_manager.rb start db router"
    puts %x[cd #{@config["storage_manager_path"]}; ruby scalarm_storage_manager.rb start db router]

    0.upto(cluster_size - 1) do |i|
      port = starting_port + i
      puts "bundle exec #{thin_start_cmd(port)}"
      system("export EUSAS_SERVER_PORT=#{port}; bundle exec #{thin_start_cmd(port)}")

      # TODO fix this registering Experiment Manager in DB
      #current_count = ExperimentManager.all.count
      #em = ExperimentManager.new({ hostname: "#{@host}:#{port}", created_at: Time.now, manager_id: current_count + 1 })
      #em.save
      #File.open("tmp/manager_#{port}.txt", "w"){|f| f.puts em.manager_id}
    end
  end

  def stop_server(starting_port, cluster_size)
    0.upto(cluster_size - 1) do |i|
      port = starting_port + i

      self.thin_procs_list(port).each do |process_line|
        pid = process_line.split(" ")[1]
        puts "kill -9 #{pid}"
        system("kill -9 #{pid}")
      end

      File.delete("tmp/pids/thin_#{port}.pid") if File.exist?("tmp/pids/thin_#{port}.pid")

      # TODO fix me
      #ExperimentManager.find_by_hostname("#{@host}:#{port}").each do |em|
      #  em.destroy
      #end
      #
      #File.delete("tmp/manager_#{port}.txt")
    end

    if thin_procs_list('').empty?
      puts "Stopping db router - cd #{@config["storage_manager_path"]}; ruby scalarm_storage_manager.rb stop db router"
      puts %x[cd #{@config["storage_manager_path"]}; ruby scalarm_storage_manager.rb stop db router]
    end
  end

  def pid_file(port)
    "tmp/pids/thin_#{port}.pid"
  end

  def thin_start_cmd(port)
    "thin -d -p #{port} -e development -l log/scalarm_#{port}.log --pid #{self.pid_file(port)} start"
  end

  def thin_procs_list(port)
    out = %x[ps aux | grep "thin.*#{port}"]
    out.split("\n").delete_if{|line| line.include? "grep"}
  end

  def download_scenarios_and_code_repository
    puts "Downloading simulation code and scenarios"
    # deleting any old files
    `cd public; rm -rf simulation_scenarios; rm repository.tar.gz`
    # downloading current versions
    download_file_from_information_service("simulation_scenarios", "scenarios.zip")
    `cd public; unzip scenarios.zip; rm scenarios.zip; mv scenarios simulation_scenarios`

    download_file_from_information_service("simulation_code", "repository.tar.gz")
  end

  private

  def download_file_from_information_service(file_name, output_file)
    sis_server, sis_port = @config["scalarm_information_service_url"].split(":")

    http = Net::HTTP.new(sis_server, sis_port.to_i)
    req = Net::HTTP::Get.new("/download_#{file_name}")

    req.basic_auth @config["information_service_login"], @config["information_service_password"]
    response = http.request(req)

    output_destination = File.join("public", output_file)
    open(output_destination, "wb") do |file|
      file.write(response.body)
    end
  end

end

# main
if ARGV.size < 3 or ['start', 'stop', 'restart', 'status'].include?(ARGV[1])
  puts "usage scalarm_experiment_manager (start|stop|restart) <starting_port> <cluster_size>"
  exit(1)
end

# TODO FIXME
if not File.exist?(File.join(".", "public", "cloud_data"))
  puts "Creating a soft link to Cloud data"
  `cd public; ln -s /cloud_data/ cloud_data`
end

sem = ScalarmExperimentManager.new
starting_port, cluster_size = ARGV[1].to_i, ARGV[2].to_i

case ARGV[0]

when "start" then
  sem.download_scenarios_and_code_repository
  sem.start_server(starting_port, cluster_size)

when "stop" then
  sem.stop_server(starting_port, cluster_size)

when "restart" then
  sem.stop_server(starting_port, cluster_size)
  sem.start_server(starting_port, cluster_size)

when 'status' then
  server_status = 0
  0.upto(cluster_size - 1) do |i|
    port = starting_port + i
    server_status += sem.thin_procs_list(port).size
  end

  if server_status == 0
    puts "Scalarm Experiment Manager is not running"
  else
    puts "Scalarm Experiment Manager is running in #{server_status} instances"
  end

end
