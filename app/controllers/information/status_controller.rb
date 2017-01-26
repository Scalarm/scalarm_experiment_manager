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
    service_classes = [ExperimentManager, StorageManager, ChartService, ExperimentSupervisor]
    states = Hash[service_classes.collect { |service_class| [service_class, collect_service_states(service_class)] }]

    status = 'ok'
    message = ''

    if states.values.any? &:empty?
      status = 'failed'
      message = 'Every service should have at least one instance'
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
      add_service_states(data, this_service_states, service_class.to_s.underscore)
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
    service_class.get_all_addresses.collect do |address|
      query_status_all(address)
    end
  end

  def add_service_states(data, states, name)
    counter = 0
    states.each do |s|
      data["#{name}#{counter+=1}".to_sym] = [s]
    end
  end

  # Queries status of serivce listening at service_address
  # Returns Hash with:
  # * status: 'failed' or 'ok' or 'warning'
  # * content (optional): an additional message
  def query_status_all(service_address, scheme='https')
    begin
      resp = RestClient.get "#{scheme}://#{service_address}/status",
                            params: { tests: ['database'] },
                            content_type: :json, accept: :json
    rescue RestClient::Exception => e
      resp = e.response
    rescue => e
      return {
        status: 'failed',
        content: "Exception on checking status for #{service_address}: #{e.to_s}"
      }
    end

    begin
      json_resp = JSON.parse(resp)
    rescue
      return {
          status: 'failed',
          content: "Invalid response (#{resp.respond_to?(:code) ? resp.code : 'none'}): \"#{resp}\""
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
