require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructuresController < ApplicationController
  include InfrastructureErrors

  def index
    render 'infrastructure/index'
  end

  def list
    render json: InfrastructureFacadeFactory.list_infrastructures
  end

  # Get Simulation Manager nodes for Infrastructure Tree for given containter name
  # and current user.
  # GET params:
  # - infrastructure_name: name of Infrastructure
  # - experiment_id: (optional) experiment_id
  # - infrastructure_params: (optional) hash with special params for infrastructure (e.g. filtering options)
  def simulation_manager_records
    begin
      facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure_name])
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

    InfrastructureFacadeFactory.get_registered_infrastructure_names.each do |infrastructure_id|
      facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_id)
      infrastructure_info[infrastructure_id] = facade.current_state(@current_user.id)
    end

    render json: infrastructure_info
  end

  # POST JSON params:
  # - experiment_id
  # - infrastructure_name - short name of infrastructure
  # - job_counter
  def schedule_simulation_managers
    infrastructure_name = '?'

    unless validate_schedule_simulation_managers(params)
      return render json: { status: 'error', error_code: 'missing-parameters', msg: I18n.t('infrastructures_controller.missing_parameters') }
    end

    begin
      infrastructure_name = params[:infrastructure_name]
      infrastructure = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
      begin
        status, response_msg = infrastructure.start_simulation_managers(
            @current_user.id, params[:job_counter].to_i, params[:experiment_id], params
        )
        render json: { status: status, msg: response_msg }
      rescue InfrastructureErrors::NoCredentialsError => no_creds
        render json: { status: 'error', error_code: 'no-credentials', msg: I18n.t('infrastructures_controller.invalid_credentials',
                                                                   name: infrastructure.long_name) }
      rescue InfrastructureErrors::InvalidCredentialsError => inv_creds
        render json: { status: 'error', error_code: 'invalid-credentials', msg: I18n.t('infrastructures_controller.invalid_credentials',
                                                                        name: infrastructure.long_name) }
      end
    rescue InfrastructureErrors::NoSuchInfrastructureError => exc
      render json: {status: 'error', error_code: 'no-such-infrastructure', msg: I18n.t('infrastructures_controller.no_such_infrastructure',
                                                                        name: infrastructure_name) }
    rescue Exception => exc
      render json: { status: 'error', error_code: 'scheduling-failed', msg: I18n.t('infrastructures_controller.schedule_error',
                        name: infrastructure ? infrastructure.long_name : infrastructure_name,
                        error: exc.to_s) }
    end
  end

  def validate_schedule_simulation_managers(params)
    %w(experiment_id job_counter infrastructure_name).all? {|p| params.include? p}
  end

  # POST params (in JSON):
  # - infrastructure_name
  def add_infrastructure_credentials
    infrastructure_name = params[:infrastructure_name]
    credentials = nil
    begin
      infrastructure = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)

      if @current_user.banned_infrastructure?(infrastructure_name)
        return render json: {
            status: 'error',
            error_code: 'banned',
            msg: t('infrastructures_controller.credentials.banned',
                   infrastructure_name: infrastructure.long_name,
                   time: @current_user.ban_expire_time(infrastructure_name)
            )
        }
      end

      credentials = infrastructure.add_credentials(@current_user, params, session)
      if credentials
        if credentials.valid?
          mark_credentials_valid(credentials, infrastructure_name)
          render json: {
              status: 'ok',
              record_id: credentials.id.to_s,
              msg: t('infrastructures_controller.credentials.success',
                     infrastructure_name: infrastructure.long_name)
          }
        else
          mark_credentials_invalid(credentials, infrastructure_name)
          render json: {
              status: 'error',
              error_code: 'invalid',
              record_id: credentials.id.to_s,
              msg: t('infrastructures_controller.credentials.invalid',
                     infrastructure_name: infrastructure.long_name)
          }
        end
      else
        raise StandardError.new(t('infrastructures_controller.credentials.nil_add_credentials'))
      end
    rescue Exception => exc
      mark_credentials_invalid(credentials, infrastructure_name)
      render json: {
          status: 'error',
          error_code: credentials ? 'unknown' : 'not-in-db',
          record_id: credentials ? credentials.id.to_s : '',
          msg: t('infrastructures_controller.credentials.internal_error',
                 infrastructure_name: infrastructure ? infrastructure.long_name : infrastructure_name,
                 error: "#{exc.class.to_s}: #{exc.to_s}")
      }
    end
  end

  def mark_credentials_valid(credentials, infrastructure_name)
    credentials.invalid = false
    if @current_user.credentials_failed and @current_user.credentials_failed.include?(infrastructure_name)
      @current_user.credentials_failed[infrastructure_name] = []
      @current_user.save
    end
    credentials.save
  end

  def mark_credentials_invalid(credentials, infrastructure_name)
    credentials.invalid = true
    @current_user.credentials_failed = {} unless @current_user.credentials_failed
    @current_user.credentials_failed[infrastructure_name] = [] unless @current_user.credentials_failed.include?(infrastructure_name)
    @current_user.credentials_failed[infrastructure_name] << Time.now
    # TODO: trim to 2 invalid attempts?
    @current_user.save
    credentials.save
  end

  # POST params (in JSON):
  # - infrastructure_name
  # - record_id
  # - credential_type (optional)
  def remove_credentials
    begin
      facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure_name])
      facade.remove_credentials(params[:record_id], @current_user.id, params[:credential_type])
      render json: {status: 'ok', msg: I18n.t('infrastructures_controller.credentials_removed', name: facade.long_name)}
    rescue Exception => e
      Rails.logger.error "Remove credentials failed: #{e.to_s}\n#{e.backtrace.join("\n")}"
      render json: {status: 'error', msg: I18n.t('infrastructures_controller.credentials_not_removed', error: e.to_s)}
    end
  end

  # GET params
  # - name - long name of the infrastructure to be displayed in view
  # - infrastructure_name
  # - group (optional)
  # All params will be passed to simulation_managers_info in view
  def simulation_managers_summary
    render partial: 'infrastructures/simulation_managers_summary',
           locals: {
               long_name: params[:name],
               partial_name: (params[:group] or params[:infrastructure_name]),
               infrastructure_name: params[:infrastructure_name],
               simulation_managers: InfrastructureFacadeFactory.get_facade_for(params[:infrastructure_name]).get_sm_records
           }
  end

  # GET params:
  # - command - one of: stop, restart; command name that will be executed on simulation manager
  # - record_id - record id of simulation manager which will execute command
  # - infrastructure_name - infrastructure id to which simulation manager belongs to
  def simulation_manager_command
    begin
      if %w(stop restart).include? params[:command]
        yield_simulation_manager(params[:record_id], params[:infrastructure_name]) do |sm|
          sm.send(params[:command])
          sm.record.destroy if params[:command] == 'stop'
        end
        render json: {status: 'ok', msg: I18n.t('infrastructures_controller.command_executed', command: params[:command])}
      else
        render json: {status: 'error', error_code: 'wrong-command', msg: I18n.t('infrastructures_controller.wrong_command', command: params[:command])}
      end
    rescue NoSuchSimulationManagerError => e
      render json: { status: 'error', error_code: 'no-such-simulation-manager', msg: t('infrastructures_controller.no_such_simulation_manager')}
    rescue AccessDeniedError => e
      render json: { status: 'error', error_code: 'access-denied', msg: t('infrastructures_controller.access_to_sm_denied')}
    rescue NoSuchInfrastructureError => e
      render json: { status: 'error', error_code: 'no-such-infrastructure', msg: t('infrastructures_controller.no_such_infrastructure', name: e.to_s)}
    rescue Exception => e
      render json: { status: 'error', error_code: 'unknown', msg: t('infrastructures_controller.command_error', error: "#{e.class.to_s} - #{e.to_s}")}
    end
  end


  # Mandatory GET params:
  # - infrastructure_name
  # - record_id
  def get_sm_dialog
    begin
      infrastructure_name = params[:infrastructure_name]

      facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
      group_name = InfrastructureFacadeFactory.get_group_for(infrastructure_name)

      render inline: render_to_string(partial: 'sm_dialog', locals: {
          facade: facade,
          record: get_sm_record(params[:record_id], facade),
          partial_name: (group_name or infrastructure_name)
      })
    rescue NoSuchInfrastructureError => e
      render inline: render_to_string(partial: 'error_dialog', locals: {message: t('infrastructures_controller.wrong_infrastructure', name: params[:infrastructure_name])})
    rescue NoSuchSimulationManagerError => e
      render inline: render_to_string(partial: 'error_dialog', locals: {message: t('infrastructures_controller.error_sm_removed')})
    rescue Exception => e
      Rails.logger.error("Exception when getting Simulation Manager: #{e.to_s}\n#{e.backtrace.join("\n")}")
      render inline: render_to_string(partial: 'error_dialog', locals: {message: t('infrastructures_controller.sm_exception', error: e.to_s)})
    end
  end

  # GET params:
  # - experiment_id (optional)
  # - infrastructure_name (optional)
  # - infrastructure_params (optional) - Hash with additional parameters, e.g. PLGrid scheduler
  def get_booster_dialog
    infrastructure_name = params[:infrastructure_name]
    group_name = InfrastructureFacadeFactory.get_group_for(infrastructure_name)

    render inline: render_to_string(partial: 'booster_dialog', locals: {
        infrastructure_name: infrastructure_name,
        form_name: (group_name or infrastructure_name),
        experiment_id: params[:experiment_id]
    })
  end

  # GET params:
  # - group (optional)
  # - infrastructure_name
  def get_booster_partial
    infrastructure_name = params[:infrastructure_name]
    group_name = InfrastructureFacadeFactory.get_group_for(infrastructure_name)
    partial_name = (group_name or infrastructure_name)
    begin
      render partial: "infrastructures/scheduler/forms/#{partial_name}", locals: {
          infrastructure_name: infrastructure_name
      }
    rescue ActionView::MissingTemplate
      render nothing: true
    end
  end

  # GET params
  # - infrastructure_name
  def get_credentials_partial
    begin
      render inline: render_to_string(partial: "infrastructure/credentials/#{params[:infrastructure_name]}")
    rescue ActionView::MissingTemplate => exc
      Rails.logger.error "Get credentials partial '#{params[:infrastructure_name]}' failed: #{exc.backtrace.join("\n")}"
      render nothing: true
    end
  end

  # GET params
  # - infrastructure_name
  def get_credentials_table_partial
    begin
      render inline: render_to_string(partial: "infrastructure/credentials/tables/#{params[:infrastructure_name]}")
    rescue ActionView::MissingTemplate => exc
      Rails.logger.error "Get credentials partial '#{params[:infrastructure_name]}' failed: #{exc.backtrace.join("\n")}"
      render nothing: true
    end
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
    facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
    facade.yield_simulation_manager(get_sm_record(record_id, facade)) {|sm| yield sm}
  end

  # TODO: unused, remove?
  # def collect_infrastructure_info(user_id)
  #   @infrastructure_info = {}
  #
  #   InfrastructureFacadeFactory.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
  #     @infrastructure_info[infrastructure_id] = infrastructure_info[:facade].pbs_state(user_id)
  #   end
  #
  #   #private_all_machines = SimulationManagerHost.all.count
  #   #private_idle_machines = SimulationManagerHost.select { |x| x.state == 'not_running' }.count
  #   #
  #   #@infrastructure_info[:private] = "Currently #{private_idle_machines}/#{private_all_machines} machines are idle."
  #   @infrastructure_info[:private] = 'Not available'
  #   @infrastructure_info[:amazon] = 'Not available'
  #   #
  #   #user_id = session[:user]
  #   #return if user_id.nil?
  #   #Rails.logger.debug('Accessing PL-Grid information')
  #   #
  #   #plgrid_jobs = PlGridJob.find_by_user_id(user_id)
  #   #plgrid_jobs
  #   #@infrastructure_info[:plgrid] = "Currently #{plgrid_jobs ||} jobs are running."
  #   # amazon_instances = (defined? @ec2_running_instances) ? @ec2_running_instances.size : 0
  #   #amazon_instances = CloudMachine.where(:user_id => user_id).count
  #   #
  #   #@infrastructure_info[:amazon] = "Currently #{amazon_instances} Virtual Machines are running."
  # end
end