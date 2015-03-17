require 'securerandom'
require 'infrastructure_facades/infrastructure_errors'

class SimulationManagersController < ApplicationController

  before_filter :set_user_id
  before_filter :load_infrastructure

  rescue_from InfrastructureErrors::NoSuchInfrastructureError, with: :handle_no_such_infrastructure_error
  rescue_from Exception, with: :handle_exception

  # Get Simulation Manager nodes in JSON
  # GET params:
  # - infrastructure: (String) name of Infrastructure
  # - experiment_id: (String) (optional) experiment_id
  # - states: (String or Array of Strings) (optional) allowed states
  # - states_not: (String or Array of Strings) (optional) not allowed states
  # - onsite_monitoring: (true/false) (optional)
  # - host: (String) private machines only, host name
  # - port: (String) private machines only, port number
  def index
    sm_records = (if @infrastructure_facade.blank?
                    get_all_sm_records(params[:experiment_id], params)
                  else
                    @infrastructure_facade.get_sm_records(@user_id, params[:experiment_id],
                                                          (Utils.parse_json_if_string(params) or {}) )
                  end)

    render json: {
        sm_records: sm_records.map(&:to_h),
        status: 'ok'
    }
  end

  def get_all_sm_records(experiment_id=nil, params=nil)
    InfrastructureFacadeFactory.get_all_sm_records(@user_id, experiment_id, params)
  end


  # TODO refactor - reuse envelope, handle exceptions

  # GET enveloped hash of single simulation manager
  def show
    result = { status: 'ok' }

    if @infrastructure_facade.blank?
      result[:status] = 'error'
      result[:msg] = t('simulation_managers.infrastructure_not_found', infrastructure: params[:infrastructure])
    else
      record = @infrastructure_facade.get_sm_record_by_id(params[:id])
      # TODO: infrastructure independent
      # record = nil
      # InfrastructureFacadeFactory.get_all_infrastructures.each do |infrastructure|
      #   record = infrastructure.get_sm_records(params[:id], @user_id)
      #   break if record
      # end
      if record and record.user_id == @user_id
        result[:record] = record.to_h
      else
        result[:status] = 'error'
      end
    end

    if result[:status] == 'ok'
      render json: result
    else
      render json: result, status: 400
    end
  end

  def code
    if @infrastructure_facade.blank?
      render inline: t('simulation_managers.infrastructure_not_found', infrastructure: params[:infrastructure]), status: 400
    else
      sm_record = @infrastructure_facade.get_sm_records(@user_id, nil).select{|sm| sm.id.to_s == params[:id]}.first

      if sm_record.blank? or sm_record.sm_uuid.blank?
        render inline: t('simulation_managers.not_found', id: params[:id]), status: 400
      else
        code_path = @infrastructure_facade.simulation_manager_code(sm_record)

        send_file code_path, type: 'application/zip'
      end
    end

  end

  def update
    sm_record = @infrastructure_facade.get_sm_records(@user_id, nil).select{|sm| sm.id.to_s == params[:id]}.first

    unless sm_record.nil?
      Utils.parse_json_if_string(params[:parameters]).each do |key, value|
        if key == 'state'
          sm_record.set_state(value.to_sym)
        elsif key == 'resource_status'
          prev_status = sm_record.resource_status
          sm_record.send("#{key}=", value.to_sym)
          # changing resource status should trigger sm monitor procedure immediately
          unless sm_record.resource_status == prev_status
            Thread.new do 
              lock = Scalarm::MongoLock.new(@infrastructure_facade.short_name)
              if lock.acquire
                begin
                  @infrastructure_facade.yield_simulation_manager(sm_record) do |sm|
                    sm.monitor
                  end
                rescue Exception => e
                  Rails.logger.error("An exception occured during SM monitoring - #{e} - #{e.backtrace.join("\n")}")
                ensure
                  lock.release
                end
              end
            end   
          end 
        else
          sm_record.send("#{key}=", value)
        end

      end

      if sm_record.save_if_exists
        render inline: 'SM updated'
      else
        render inline: 'SM not updated', status: 404
      end
    else
      render inline: 'SM not found', status: 404
    end
  end

  # -- filters --

  def set_user_id
    @user_id = @sm_user.blank? ? @current_user.id : @sm_user.user_id
  end

  def load_infrastructure
    @infrastructure_facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure]) if params.include? :infrastructure
  end

  # -- error handling --

  def handle_no_such_infrastructure_error
    render json: {
        status: 'error',
        msg: t('simulation_managers.infrastructure_not_found', infrastructure: params[:infrastructure])
    }, status: 400
  end

  def handle_exception(exception)
    render json: {
        status: 'error',
        msg: "#{exception.class.to_s}: #{exception.to_s} in line #{exception.backtrace[0].split(':')[-2]}"
    }, status: 500
  end

end
