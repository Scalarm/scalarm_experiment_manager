require 'infrastructure_facades/infrastructure_errors'

class InfrastructuresController < ApplicationController
  include InfrastructureErrors

  def index
    render 'infrastructure/index'
  end

  def list
    render json: InfrastructureFacade.list_infrastructures
  end

  # Get Simulation Manager nodes for Infrastructure Tree for given containter name
  # and current user.
  # GET params:
  # - infrastructure_name: name of Infrastructure
  # - experiment_id: (optional) experiment_id
  # - infrastructure_params: (optional) hash with special params for infrastructure (e.g. filtering options)
  def simulation_manager_records
    begin
      facade = InfrastructureFacade.get_facade_for(params[:infrastructure_name])
      hash = facade.sm_record_hashes(@current_user.id, params[:experiment_id], (params[:infrastructure_params] or {}))
      render json: hash
    rescue NoSuchInfrastructureError => e
      Rails.logger.error "Try to fetch SM nodes, but requested infrastructure does not exist: #{e.to_s}"
      render json: []
    rescue Exception => e
      Rails.logger.error "Exception on fetching SM nodes (#{params.to_s}): #{e.to_s}\n#{e.backtrace.join("\n")}"
      render json: []
    end
  end

  def infrastructure_info
    infrastructure_info = {}

    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure|
      infrastructure_info[infrastructure_id] = infrastructure[:facade].current_state(@current_user.id)
    end

    render json: infrastructure_info
  end

  def schedule_simulation_managers
    experiment_id = (params[:experiment_id] or nil)

    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status, response_msg = infrastructure.start_simulation_managers(@current_user, params[:job_counter].to_i, experiment_id, params)

    render json: { status: status, msg: response_msg }
  end

  def add_infrastructure_credentials
    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status = infrastructure.add_credentials(@current_user, params, session)

    render json: { status: status, msg: I18n.t("#{params[:infrastructure_type]}.login.#{status}") }
  end


  # GET param: infrastructure_name
  # GET param: record_id
  # GET param (optional): credential_type
  def remove_credentials
    begin
      facade = InfrastructureFacade.get_facade_for(params[:infrastructure_name])
      facade.remove_credentials(params[:record_id], @current_user.id, params[:credential_type])
      render json: {status: 'ok', msg: I18n.t('infrastructures_controller.credentials_removed', name: facade.long_name)}
    rescue Exception => e
      Rails.logger.error "Remove credentials failed: #{e.to_s}\n#{e.backtrace.join("\n")}"
      render json: {status: 'error', msg: I18n.t('infrastructures_controller.credentials_not_removed', error: e.to_s)}
    end
  end

  def simulation_managers_info
    begin
      infrastructure_facade = if params[:infrastructure_name] == 'cloud'
                               InfrastructureFacade.get_facade_for(params[:cloud_name])
                              else
                               InfrastructureFacade.get_facade_for(params[:infrastructure_name])
                              end

      @current_state_summary = infrastructure_facade.current_state(@current_user)
      @simulation_managers = infrastructure_facade.get_sm_records(@current_user.id)

      render partial: "infrastructure/information/simulation_managers/#{params[:infrastructure_name]}"
    rescue Exception => e
      # FIXME translate
      Rails.logger.error "Error rendering simulation_managers_info: #{e.to_s}\n#{e.backtrace.join("\n")}"
      render text: "An error occured: #{e.to_s}"
    end
  end

  # FIXME locals
  def simulation_manager_command
    begin
      if %w(stop restart).include? params[:command]
        yield_simulation_manager(params[:record_id], params[:infrastructure_name]) do |sm|
          sm.send(params[:command])
          sm.record.destroy if params[:command] == 'stop'
        end
        render json: {status: 'ok', msg: "Executed #{params[:command]} on Simulation Manager"}
      else
        render json: {status: 'error', msg: "No such command for Simulation Manager: #{params[:command]}"}
      end
    rescue NoSuchSimulationManagerError => e
      render json: { status: 'error', msg: "No such Simulation Manager" }
    rescue AccessDeniedError => e
      render json: { status: 'error', msg: "Access to Simulation Manager denied" }
    rescue Exception => e
      render json: { status: 'error', msg: "Error on Simulation Manager command invocation: #{e.to_s}" }
    end
  end


  # TODO locals
  # Mandatory GET params:
  # - infrastructure_name
  # - record_id
  def get_sm_dialog
    begin
      @facade = InfrastructureFacade.get_facade_for(params[:infrastructure_name])
      @sm_record = get_sm_record(params[:record_id], @facade)
      render inline: render_to_string(partial: 'sm_dialog')
    rescue NoSuchInfrastructureError => e
      render json: { status: 'error', msg: "No infrastructure: #{params[:infrastructure_name]}" }
    rescue NoSuchSimulationManagerError => e
      render json: { status: 'error', msg: "No such Simulation Manager" }
    rescue Exception => e
      render json: { status: 'error', msg: "Exception when getting Simulation Manager #{params['resource_id']}@#{params['sm_container']}: #{e}" }
    end
  end

  # GET params:
  # - experiment_id (optional)
  # - infrastructure_name (optional)
  # - infrastructure_params (optional) - Hash with additional parameters, e.g. PLGrid scheduler
  def get_booster_dialog
    render inline: render_to_string(partial: 'booster_dialog')
  end

  # ============================ PRIVATE METHODS ============================
  private

  # Get single SimulationManagerRecord with priviliges check
  def get_sm_record(record_id, facade)
    record = facade.get_sm_record_by_id(record_id)
    raise NoSuchSimulationManagerError if record.nil?
    raise AccessDeniedError if record.user_id.to_s != @current_user.id.to_s
    record
  end

  # Yield single SimulationManager with priviliges check
  # This method automatically clean up infrastructure facade resources
  def yield_simulation_manager(record_id, infrastructure_name, &block)
    facade = InfrastructureFacade.get_facade_for(infrastructure_name)
    facade.yield_simulation_manager(get_sm_record(record_id, facade)) {|sm| yield sm}
  end

  def collect_infrastructure_info(user_id)
    @infrastructure_info = {}

    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
      @infrastructure_info[infrastructure_id] = infrastructure_info[:facade].pbs_state(user_id)
    end

    #private_all_machines = SimulationManagerHost.all.count
    #private_idle_machines = SimulationManagerHost.select { |x| x.state == 'not_running' }.count
    #
    #@infrastructure_info[:private] = "Currently #{private_idle_machines}/#{private_all_machines} machines are idle."
    @infrastructure_info[:private] = 'Not available'
    @infrastructure_info[:amazon] = 'Not available'
    #
    #user_id = session[:user]
    #return if user_id.nil?
    #Rails.logger.debug('Accessing PL-Grid information')
    #
    #plgrid_jobs = PlGridJob.find_by_user_id(user_id)
    #plgrid_jobs
    #@infrastructure_info[:plgrid] = "Currently #{plgrid_jobs ||} jobs are running."
    # amazon_instances = (defined? @ec2_running_instances) ? @ec2_running_instances.size : 0
    #amazon_instances = CloudMachine.where(:user_id => user_id).count
    #
    #@infrastructure_info[:amazon] = "Currently #{amazon_instances} Virtual Machines are running."
  end
end