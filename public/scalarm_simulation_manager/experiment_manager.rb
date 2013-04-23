require 'json'
require 'uri'
require 'openssl'
require 'net/https'

class ExperimentManager

  def initialize(config)
    @experiment_manager_address = config['experiment_manager_address']
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

  def mark_as_complete(experiment_id, simulation_id, results)
    uri = URI(path_to("#{experiment_id}/simulations/#{simulation_id}/mark_as_complete"))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.request_uri)
    request.basic_auth(@user, @pass)
    request.set_form_data({ 'result' => results.to_json })

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