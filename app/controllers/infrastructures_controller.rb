require 'infrastructure_facades/infrastructure_facade_factory'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructuresController < ApplicationController
  include InfrastructureErrors
  include GenericErrors

  # GET params:
  # - experiment_id: (optional) experiment_id
  def index
    validate(
        experiment_id: [:optional, :security_default]
    )

    render 'infrastructure/index', locals: { experiment_id: params[:experiment_id].to_s }
  end

  def list
    render json: InfrastructureFacadeFactory.list_infrastructures(current_user.id)
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
      hash = facade.sm_record_hashes(current_user.id, params[:experiment_id], (params[:infrastructure_params] or {}))
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
      infrastructure_info[infrastructure_id] = facade.current_state(current_user.id)
    end

    render json: infrastructure_info
  end

  # POST JSON params:
  # - experiment_id
  # - infrastructure_name - short name of infrastructure
  # - job_counter
  def schedule_simulation_managers
    validate(
        infrastructure_name: [:security_default],
        experiment_id: [:security_default],
        job_counter: [:security_default, :integer, :positive],
        time_limit: [:optional, :integer, :positive]
    ) #:queue
    infrastructure = nil
    infrastructure_name = '?'

    params['time_limit'] = params[:time_limit] = 60 if params[:time_limit].nil?

    begin
      experiment_id = params[:experiment_id]
      begin
        validate_experiment(experiment_id)
      rescue InfrastructureErrors::AccessDeniedError => access_denied
        return render json: {status: 'error', error_code: 'foreign-experiment', msg: I18n.t('infrastructures_controller.foreign_experiment')}
      end

      infrastructure_name = params[:infrastructure_name]
      infrastructure = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
      begin
        # add proxy from ApplicationController (if available) if not explicitly passed specified in params
        params[:proxy] = @proxy_s if @proxy_s
        records = infrastructure.start_simulation_managers(
            current_user.id, params[:job_counter].to_i, experiment_id, params
        )
        render json: { status: 'ok', records_ids: (records.map {|r| r.id.to_s}), infrastructure: infrastructure_name,
                       msg: I18n.t('infrastructures_controller.scheduled_info', count: records.count.to_s, name: infrastructure.long_name) }
      rescue InfrastructureErrors::ScheduleError => schedule_error
        render json: { status: 'error', error_code: 'scheduling-failed',
                       msg: I18n.t('infrastructures_controller.schedule_error', name: infrastructure.long_name,
                                   error: schedule_error.to_s) }
      rescue InfrastructureErrors::NoCredentialsError => no_creds
        render json: { status: 'error', error_code: 'no-credentials', msg: I18n.t('infrastructures_controller.no_credentials',
                                                                   name: infrastructure.long_name) }
      rescue InfrastructureErrors::InvalidCredentialsError => inv_creds
        render json: { status: 'error', error_code: 'invalid-credentials', msg: I18n.t('infrastructures_controller.invalid_credentials',
                                                                        name: infrastructure.long_name) }
      end
    rescue InfrastructureErrors::NoSuchInfrastructureError => exc
      render json: {status: 'error', error_code: 'no-such-infrastructure', msg: I18n.t('infrastructures_controller.no_such_infrastructure',
                                                                        name: infrastructure_name) }
    rescue GenericErrors::ControllerError => error
      render json: { status: 'error', error_code: error.error_code, msg: I18n.t('infrastructures_controller.schedule_error',
                         name: infrastructure ? infrastructure.long_name : infrastructure_name,
                         error: error.to_s) }
      Rails.logger.error "#{error.class.to_s} #{error.to_s}\n#{error.backtrace.join("\n")}"
    rescue Exception => exc
      render json: { status: 'error', error_code: 'scheduling-failed', msg: I18n.t('infrastructures_controller.schedule_error',
                        name: infrastructure ? infrastructure.long_name : infrastructure_name,
                        error: exc.to_s) }
      Rails.logger.error "#{exc.class.to_s} #{exc.to_s}\n#{exc.backtrace.join("\n")}"
    end
  end

  # POST params (in JSON):
  # - infrastructure_name
  def add_infrastructure_credentials
    infrastructure_name = params[:infrastructure_name]
    credentials = nil
    begin
      infrastructure = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)

      if current_user.banned_infrastructure?(infrastructure_name)
        return render json: {
            status: 'error',
            error_code: 'banned',
            msg: t('infrastructures_controller.credentials.banned',
                   infrastructure_name: infrastructure.long_name,
                   time: current_user.ban_expire_time(infrastructure_name)
            )
        }
      end

      credentials = infrastructure.add_credentials(current_user, stripped_params_values(params), session)
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
      mark_credentials_invalid(credentials, infrastructure_name) if credentials
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

  ALLOWED_CREDENTIALS_SEARCH_KEYS = [
      :host,
      :login,
      :port,
      :image_identifier,
      :cloud_name
  ]

  # GET params (in JSON):
  # - infrastructure - name of infrastructure
  # - query_params - Hash of additional filtering options
  # Successful result:
  # {"status": "ok", "data": [<array of credentials objects>]}
  def get_infrastructure_credentials
    validate(
        infrastructure: :security_default
    )

    query_params =
        (params.include?(:query_params) ? Scalarm::ServiceCore::Utils.parse_json_if_string(params[:query_params]).to_h : {})
    raise SecurityError.new('Additional params should be Hash') unless query_params.kind_of? Hash

    raise SecurityError.new('All additional params values should be strings or integers') unless query_params.all? do |k, v|
      (k.kind_of?(String) || k.kind_of?(Symbol)) and (v.kind_of?(String) || v.kind_of?(Fixnum))
    end

    query_params.symbolize_keys!

    unless query_params.keys.all? {|k| ALLOWED_CREDENTIALS_SEARCH_KEYS.include?(k)}
      raise SecurityError.new("The only allowed credentials search keys are: #{ALLOWED_CREDENTIALS_SEARCH_KEYS.join(', ')}")
    end

    ## old code for blacklisting, now using whitelisting
    # raise SecurityError.new('Using user_id in query is forbidden') if query_params.include?('user_id')
    # raise SecurityError.new('Using secrets_* in query is forbidden') if query_params.any? {|k, v| k =~ /secret_.*/}

    infrastructure_name = params[:infrastructure]
    begin
      infrastructure = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
      records = infrastructure.get_credentials(current_user.id, query_params)

      # modify records to contain only non-secret fields
      hashes = records.collect do |r|
        r.to_h.select { |k, v| !(k =~ /secret_.*/) }
      end

      render json: {
        status: 'ok',
        data: hashes
      }

    rescue NoSuchInfrastructureError => exc
      render json: {
          status: 'error',
          msg: "No such infrastructure: #{infrastructure_name}"
      }
    rescue Exception => exc
      render json: {
          status: 'error',
          msg: "Internal error: #{exc.to_s}"
      }
    end

  end

  def stripped_params_values(params)
    Hash[params.map {|k, v| [k.to_sym, v.respond_to?(:strip) ? v.strip : v]}]
  end

  def mark_credentials_valid(credentials, infrastructure_name)
    credentials.invalid = false
    if current_user.credentials_failed and current_user.credentials_failed.include?(infrastructure_name)
      current_user.credentials_failed[infrastructure_name] = []
      current_user.save
    end
    credentials.save
  end

  def mark_credentials_invalid(credentials, infrastructure_name)
    credentials.invalid = true
    current_user.credentials_failed = {} unless current_user.credentials_failed
    current_user.credentials_failed[infrastructure_name] = [] unless current_user.credentials_failed.include?(infrastructure_name)
    current_user.credentials_failed[infrastructure_name] << Time.now
    # TODO: trim to 2 invalid attempts?
    current_user.save
    credentials.save
  end

  # POST params (in JSON):
  # - infrastructure_name
  # - record_id
  # - credential_type (optional)
  def remove_credentials
    validate(
        infrastructure_name: :security_default,
        record_id: :security_default,
        credential_type: [:optional, :security_default]
    )

    begin
      facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure_name])
      facade.remove_credentials(params[:record_id], current_user.id, params[:credential_type])
      render json: {status: 'ok', msg: I18n.t('infrastructures_controller.credentials_removed', name: facade.long_name)}
    rescue Exception => e
      Rails.logger.error "Remove credentials failed: #{e.to_s}\n#{e.backtrace.join("\n")}"
      render json: {status: 'error', msg: I18n.t('infrastructures_controller.credentials_not_removed', error: e.to_s)}
    end
  end

  # GET params
  # - infrastructure_name
  # All params will be passed to simulation_managers_info in view
  def simulation_managers_summary
    validate(
        infrastructure_name: :security_default
    )

    infrastructure_name = params[:infrastructure_name]
    facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
    group = InfrastructureFacadeFactory.get_group_for(infrastructure_name)
    render partial: 'infrastructures/simulation_managers_summary',
           locals: {
               long_name: facade.long_name,
               partial_name: (group or params[:infrastructure_name]),
               infrastructure_name: params[:infrastructure_name],
               simulation_managers: facade.get_sm_records(current_user.id).to_a
           }
  end

=begin
  @api {post} /infrastructure/simulation_manager_command Invoke command on this Infrastructure's SimulationManager
  @apiName SimulationManagerCommand
  @apiGroup Infrastructures

  @apiParam {String=stop,restart,destroy_record} command
  @apiParam {String} record_id SimulationManager ID
  @apiParam {String} infrastructure_name Name of infrastructure

  @apiSuccess {String=ok,error} status
  @apiSuccess {String} msg Message
  @apiSuccess {String=stop,restart,destroy_record} [command] Name of command which was tried to be invoked

  @apiSuccess {String=wrong-command,no-such-simulation-manager,access-denied,no-such-infrastructure,unknown} [error_code]
    Error code in case of command invocation failure
=end
  def simulation_manager_command
    validate(
        command: :security_default,
        record_id: :security_default,
        infrastructure_name: :security_default
    )

    begin
      command = params[:command]
      if %w(stop restart destroy_record).include? command
        yield_simulation_manager(params[:record_id], params[:infrastructure_name]) do |sm|
          sm.send(params[:command])
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
    validate(
        experiment_id: [:optional, :security_default],
        infrastructure_name: [:optional, :security_default]
    )

    infrastructure_name = params[:infrastructure_name]
    group_name = InfrastructureFacadeFactory.get_group_for(infrastructure_name)

    render inline: render_to_string(partial: 'booster_dialog', locals: {
        infrastructure_name: infrastructure_name,
        form_name: (group_name or infrastructure_name),
        experiment_id: params[:experiment_id]
    })
  end

  # TODO: check values like enums
  # GET params:
  # - infrastructure_name
  # - other_params - Hash
  def get_booster_partial
    validate(
        infrastructure_name: :security_default
    )

    infrastructure_name = params[:infrastructure_name]
    group_name = InfrastructureFacadeFactory.get_group_for(infrastructure_name)
    facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
    partial_name = (group_name or infrastructure_name)
    begin
      render partial: "infrastructures/scheduler/forms/#{partial_name}", locals: {
          infrastructure_name: infrastructure_name,
          other_params: facade.other_params_for_booster(current_user.id)
      }
    rescue ActionView::MissingTemplate
      render nothing: true
    end
  end

  # GET params
  # - infrastructure_name
  def get_credentials_partial
    validate(
        infrastructure_name: :security_default
    )

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
    validate(
        infrastructure_name: :security_default
    )

    begin
      render inline: render_to_string(partial: "infrastructure/credentials/tables/#{params[:infrastructure_name]}")
    rescue ActionView::MissingTemplate => exc
      Rails.logger.error "Get credentials partial '#{params[:infrastructure_name]}' failed: #{exc.backtrace.join("\n")}"
      render nothing: true
    end
  end

  # GET params
  # - infrastructure_name
  # - record_id
  def get_resource_status
    validate(
        infrastructure_name: :security_default,
        record_id: :security_default
    )

    begin
      facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure_name])
      record = get_sm_record(params[:record_id], facade)
      facade.yield_simulation_manager(record) do |sm|
        render text: t("infrastructures.sm_dialog.resource_states.#{(sm.resource_status or :error).to_s}",
                         default: t('infrastructures.sm_dialog.resource_states.unknown', state: sm.resource_status.to_s))
      end
    rescue Exception => error
      render text: t('infrastructures.sm_dialog.resource_state_error', error: error.to_s)
    end
  end


  # Get single SimulationManagerRecord with priviliges check
  def get_sm_record(record_id, facade)
    record = facade.get_sm_record_by_id(record_id)
    raise NoSuchSimulationManagerError if record.nil?
    raise AccessDeniedError if record.user_id.to_s != current_user.id.to_s
    record
  end

  # Yield single SimulationManager with priviliges check
  # This method automatically clean up infrastructure facade resources
  def yield_simulation_manager(record_id, infrastructure_name, &block)
    facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_name)
    facade.yield_simulation_manager(get_sm_record(record_id, facade)) {|sm| yield sm}
  end

  def validate_experiment(experiment_id)
    experiment = Experiment.find_by_id(experiment_id)
    if experiment
      unless experiment.user_id == current_user.id or experiment.shared_with.include? current_user.id
        raise InfrastructureErrors::AccessDeniedError
      end
    else
      raise GenericErrors::ControllerError.new('no-such-experiment', experiment_id)
    end
  end

  # ============================ PRIVATE METHODS ============================
  private :get_sm_record, :yield_simulation_manager, :validate_experiment

end