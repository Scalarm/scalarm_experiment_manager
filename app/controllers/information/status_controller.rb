require 'xmlsimple'
require 'restclient'

class Information::StatusController < ApplicationController
  rescue_from StandardError, with: :last_rescue

  def last_rescue(exception)
    Rails.logger.error("Fatal error on status check: #{exception.to_s}\n#{exception.backtrace.join("\n")}")
    status = 'failed'
    message = "Fatal error: #{exception.to_s}; see logs for details."
    http_status = :internal_server_error
    data = {
        date: Time.now,
        status: status,
        message: message
    }
    respond_to do |format|
      format.html do
        render text: json_pretty(data),
               status: http_status
      end

      format.json do
        render json: data, status: http_status
      end

      format.xml do
        render xml: convert_status_to_xml(data), status: http_status
      end
    end
  end

  def status
    render nothing: true, status: :ok
  end

  def scalarm_status
    service_controllers_classes = [
      Information::ExperimentsController,
      Information::ChartController,
      Information::SupervisorController,
    ]
    states = Hash[
      service_controllers_classes.collect do |service_class|
        [service_class, collect_service_states(service_class)]
      end
    ]

    status = 'ok'
    message = ''

    if states.values.any?(&:empty?)
      status = 'failed'
      message = 'Every service should have at least one instance.'
    elsif any_service_in_state?('failed', *states.values)
      status = 'failed'
      message = 'One or more service failed. Please check service details.'
    elsif any_service_in_state?('warning', *states.values)
      status = 'warning'
      message = 'One or more service has warnings. Please check service details.'
    end

    # response status for nagios probe: ok, failed, warning
    data = {
        date: Time.now,
        status: status, message: message
    }

    states.each do |service_class, this_service_states|
      add_service_states(
        data,
        this_service_states,
        service_class.service_name.parameterize
      )
    end

    respond_to do |format|
      format.html do
        render text: json_pretty(data),
               status: :ok
      end
      format.json do
        render json: data, status: :ok
      end
      format.xml do
        render xml: convert_status_to_xml(data), status: :ok
      end
    end
  end

  def convert_status_to_xml(data)
    XmlSimple.xml_out(data,
                      AttrPrefix: false,
                      RootName: 'healthdata',
                      ContentKey: :content)
  end


  def any_service_in_state?(for_status, *service_states)
    service_states.any? do |states_set|
      states_set.any? {|s| s[:status] == for_status}
    end
  end

  def collect_service_states(service_class)
    controller_instance = service_class.new
    # pushing request into specific controller, because we need host_with_port
    controller_instance.request = request
    controller_instance.generate_address_list.collect do |address|
      query_status_all(address)
    end
  end

  def add_service_states(data, states, name)
    counter = 0
    states.each do |s|
      data["#{name}#{counter+=1}".to_sym] = [s]
    end
  end

  # IMPORTANT NOTE: this method will work only if server has at least 2 workers!
  #                 because it needs to ping its Experiment Manager status
  #                 which is server by the same Rails app
  # Queries status of serivce listening at service_address
  # Returns Hash with:
  # * status: 'failed' or 'ok' or 'warning'
  # * content (optional): an additional message
  def query_status_all(service_address, scheme='https')
    status_url = "#{scheme}://#{service_address}/status.json"
    begin
      status_request = RestClient::Request.new(
        method: :get,
        url: status_url,
        params: { tests: ['database'] },
        content_type: :json,
        accept: :json,
        timeout: 20,
        verify_ssl: OpenSSL::SSL::VERIFY_NONE,
      )
      Rails.logger.info("Will make status request to: #{status_url}")
      resp = status_request.execute
    rescue RestClient::Exception => e
      return {
        status: 'failed',
        content: "Status check request failed for #{service_address} (GET #{status_url}): #{e}, body: #{e.response}"
      }
    rescue => e
      return {
        status: 'failed',
        content: "Exception on checking status for #{service_address} (GET #{status_url}): #{e}"
      }
    end

    begin
      json_resp = JSON.parse(resp)
    rescue Exception => e
      Rails.logger.error("query_status_all: #{e}")
      return {
          status: 'failed',
          content: "Cannot parse response of GET #{status_url} " \
            "(code: #{resp.respond_to?(:code) ? resp.code : 'none'}), error: " \
            "#{e}"
      }
    end

    if resp.code == 200
      result = {
          status: ((json_resp['status'] == 'ok') and 'ok' or 'warning')
      }
      result[:content] = json_resp['message'] if json_resp['message']
    else
      result = {
          status: 'failed'
      }
      result[:content] = (if json_resp['message']
                           "Code #{resp.code}, message: #{json_resp['message']}"
                         else
                           "Error withoud message (code #{resp.code}): \"#{resp}\""
                         end)
    end

    result
  end


  def json_pretty(data)
    JSON.pretty_generate(data)
        .gsub("\n", '<br/>')
        .gsub(' ', '&nbsp;')
  end


  private :query_status_all, :add_service_states, :any_service_in_state?,
          :collect_service_states, :convert_status_to_xml
end
