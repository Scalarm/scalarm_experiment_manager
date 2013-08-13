require 'json'
require 'uri'
require 'openssl'
require 'net/https'

class InformationService

  def initialize(config)
    @information_service_url = config['information_service_url']
  end

  def get_experiment_managers
    url = path_to('experiments/list')

    status, body = execute_http_get(url)

    if status == '200'
      JSON.parse(body)
    else
      []
    end
  end

  def get_storage_managers
    url = path_to('storage/list')

    status, body = execute_http_get(url)

    if status == '200'
      JSON.parse(body)
    else
      []
    end
  end

  def path_to(method)
    "https://#{@information_service_url}/#{method}"
  end

  def execute_http_get(url)
    uri = URI(url)
    puts "[information_service] We will request '#{uri}'"

    req = Net::HTTP::Get.new(uri.path)

    ssl_options = { use_ssl: true, ssl_version: :SSLv3, verify_mode: OpenSSL::SSL::VERIFY_NONE }
    response = Net::HTTP.start(uri.host, uri.port, ssl_options) { |http| http.request(req) }

    return response.code, response.body
  end

end