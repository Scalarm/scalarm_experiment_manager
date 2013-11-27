require 'uri'
require 'openssl'
require 'net/https'

class StorageManagerProxy

  def initialize(config)
    @config = config['storage_manager']
  end

  def delete_binary_output(experiment_id, simulation_id)
    uri = URI("https://#{@config['address']}/experiment/#{experiment_id}/simulation/#{simulation_id}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Delete.new(uri.request_uri)
    request.basic_auth(@config['user'], @config['pass'])

    begin
      response = http.request(request)

      response.code == '200'
    rescue Exception => e
      Rails.logger.debug("Exception during communication with Storage manager")

      false
    end
  end

  def delete_experiment_output(experiment_id, experiment_size)
    uri = URI("https://#{@config['address']}/experiment/#{experiment_id}/from/1/to/#{experiment_size}")
    Rails.logger.debug("using URL: #{uri} to delete experiment output")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :SSLv3
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Delete.new(uri.request_uri)
    request.basic_auth(@config['user'], @config['pass'])

    begin
      response = http.request(request)

      response.code == '200'
    rescue Exception => e
      Rails.logger.debug("Exception during communication with Storage manager: #{e}")

      false
    end
  end

  def download_binary_output_link(experiment_id, simulation_id)
    "https://#{@config['address']}/experiment/#{experiment_id}/simulation/#{simulation_id}"
  end

end