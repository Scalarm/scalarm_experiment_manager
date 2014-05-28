require 'json'
require 'uri'
require 'openssl'
require 'net/https'

class ExperimentManager

  def initialize(url, config)
    @experiment_manager_address = url
    @user = config['experiment_manager_user']
    @pass = config['experiment_manager_pass']
  end

  def get_experiment_id
    execute_http_get(experiment_id_path)
  end

  def experiment_id_path
    path_to('get_experiment_id')
  end

  def code_base(experiment_id)
    execute_http_get(code_base_path(experiment_id))
  end

  def code_base_path(experiment_id)
    path_to("#{experiment_id}/code_base")
  end

  def next_simulation(experiment_id)
    execute_http_get(next_simulation_path(experiment_id))
  end

  def next_simulation_path(experiment_id)
    path_to("#{experiment_id}/next_simulation")
  end

  def send_results_from(file, intermediate, experiment_id, simulation_id)
    process = intermediate ? "progress monitor" : "em"

    if File.exists?(file)
      puts "[#{process}] Reading results from #{file}"
      results = JSON.parse(IO.read(file))

      if results['status'] == 'ok'
        puts "[#{process}] Everything went well -> uploading the following results: #{results['results']}"
        response = if intermediate 
          report_intermediate_result(experiment_id, simulation_id, results['results'])
        else
          mark_as_complete(experiment_id, simulation_id, results['results'])
        end
      
        puts "[#{process}] We got the following response: #{response}"          
      end

    else
      puts "[#{process}] No results available"
    end
  end

  def mark_as_complete(experiment_id, simulation_id, results)
    uri = URI(path_to("#{experiment_id}/simulations/#{simulation_id}/mark_as_complete"))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    cpu_info = {}
    cmd_out = %x[cat /proc/cpuinfo | grep name | head -1]

    unless cmd_out.empty?
      cmd_out = cmd_out.split(':').last.strip
      cpu_info = { model: cmd_out }
      cmd_out = %x[cat /proc/cpuinfo | grep MHz | head -1]
      cmd_out = cmd_out.split(':').last.strip
      cpu_info[:clock] = cmd_out.to_i
    end

    request = Net::HTTP::Post.new(uri.request_uri)
    request.basic_auth(@user, @pass)
    request.set_form_data({'result' => results.to_json, cpu_info: cpu_info.to_json})

    http.request(request).body
  end

  def report_intermediate_result(experiment_id, simulation_id, results)
    uri = URI(path_to("#{experiment_id}/simulations/#{simulation_id}/progress_info"))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.request_uri)
    request.basic_auth(@user, @pass)
    request.set_form_data({'result' => results.to_json})

    http.request(request).body
  end

  def path_to(method)
    "https://#{@experiment_manager_address}/experiments/#{method}"
  end

  def execute_http_get(url)
    uri = URI(url)
    puts "We will request '#{uri}'"

    req = Net::HTTP::Get.new(uri.path)
    req.basic_auth(@user, @pass)

    ssl_options = { use_ssl: true, ssl_version: :SSLv3, verify_mode: OpenSSL::SSL::VERIFY_NONE }
    response = Net::HTTP.start(uri.host, uri.port, ssl_options) { |http| http.request(req) }

    response.body
  end

end