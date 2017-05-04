require 'uri'
require 'openssl'
require 'net/https'

class StorageManagerProxy

  def initialize(config, temp_password)
    @config = config['storage_manager']
    @temp_password = temp_password
  end

  def self.create(experiment_id)
    storage_manager_url = Information::StorageManager.all.map(&:address).sample

    if not storage_manager_url.nil?
      sm_uuid = SecureRandom.uuid
      temp_password = SimulationManagerTempPassword.create_new_password_for(sm_uuid, experiment_id)

      config = {'storage_manager' => {'address' => storage_manager_url, 'user' => sm_uuid, 'pass' => temp_password.password}}

      StorageManagerProxy.new(config, temp_password)
    else
      nil
    end
  end

  def delete_binary_output(experiment_id, simulation_id)
    uri = URI(LogBankUtils::simulation_run_binaries_url(@config['address'], experiment_id, simulation_id, nil))
    Rails.logger.debug("URI: #{uri}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # TODO: check if requests are working
    # http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Delete.new(uri.request_uri)
    request.basic_auth(@config['user'], @config['pass'])

    begin
      response = http.request(request)

      response.code == '200'
    rescue => e
      Rails.logger.debug("Exception during communication with Storage manager: #{e.to_s}")

      false
    end
  end

  def delete_stdout(experiment_id, simulation_id)
    uri = URI(LogBankUtils::simulation_run_stdout_url(@config['address'], experiment_id, simulation_id, nil))
    Rails.logger.debug("URI: #{uri}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # TODO: check if requests are working
    # http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Delete.new(uri.request_uri)
    request.basic_auth(@config['user'], @config['pass'])

    begin
      response = http.request(request)

      response.code == '200'
    rescue => e
      Rails.logger.debug("Exception during communication with Storage manager: #{e.to_s}")

      false
    end
  end

  def delete_experiment_output(experiment_id, experiment_size)
    uri = URI("https://#{@config['address']}/experiment/#{experiment_id}/from/1/to/#{experiment_size}")
    Rails.logger.debug("using URL: #{uri} to delete experiment output")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # TODO: check if requests are working
    # http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Delete.new(uri.request_uri)
    request.basic_auth(@config['user'], @config['pass'])

    begin
      response = http.request(request)

      response.code == '200'
    rescue => e
      Rails.logger.debug("Exception during communication with Storage manager: #{e.to_s}")

      false
    end
  end

  def download_binary_output_link(experiment_id, simulation_id)
    "https://#{@config['address']}/experiment/#{experiment_id}/simulation/#{simulation_id}"
  end

  def teardown
    @temp_password.destroy
  end

end