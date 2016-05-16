require 'json'
require 'simulation'
require 'csv'
require 'rest_client'

class SimulationsController < ApplicationController
  include AdaptersSetup
  before_filter :load_simulation, only: [:show, :progress_info, :progress_info_history, :mark_as_complete, :results_binaries, :results_stdout, :update]

  def index
    respond_to do |format|
      format.html do
        @simulations = current_user.get_simulation_scenarios
        @simulation_scenarios = @simulations
        @input_writers = SimulationInputWriter.find_all_by_user_id(current_user.id)
        @executors = SimulationExecutor.find_all_by_user_id(current_user.id)
        @output_readers = SimulationOutputReader.find_all_by_user_id(current_user.id)
        @progress_monitors = SimulationProgressMonitor.find_all_by_user_id(current_user.id)
      end

      format.json do
        simulation_scenarios = current_user.simulation_scenarios.where([], {fields: ["_id"]}).map { |obj| obj.id.to_s }
        render json: (
        if simulation_scenarios
          {status: 'ok', simulation_scenarios: simulation_scenarios}
        else
          {status: 'error', error_code: 'not_found'}
        end
        )
      end
    end

  end

  def registration
    @input_writers = SimulationInputWriter.find_all_by_user_id(current_user.id).map { |ex| [ex.name, ex._id] }
    @executors = SimulationExecutor.find_all_by_user_id(current_user.id).map { |ex| [ex.name, ex._id] }
    @output_readers = SimulationOutputReader.find_all_by_user_id(current_user.id).map { |ex| [ex.name, ex._id] }
    @progress_monitors = SimulationProgressMonitor.find_all_by_user_id(current_user.id).map { |ex| [ex.name, ex._id] }
  end

  def upload_component
    adapter_list = ['input_writer', 'executor', 'output_reader', 'progress_monitor']
    if adapter_list.include? params['component_type']
      adapter_name = ('Simulation'+params['component_type'].to_s.camelize).constantize
      adapter = adapter_name.new({name: params['component_name'], code: (Utils.read_if_file(params['component_code']).gsub(/\r\n/, "\n")), user_id: current_user.id})
      adapter.save
    end
    flash[:notice] = t('new_adapter_added')

    redirect_to :action => :index
  end

  def destroy_component
    if params['component_type'] == 'input_writer'
      SimulationInputWriter.find_by_id(params['component_id'].to_s).destroy
    elsif params['component_type'] == 'executor'
      SimulationExecutor.find_by_id(params['component_id'].to_s).destroy
    elsif params['component_type'] == 'output_reader'
      SimulationOutputReader.find_by_id(params['component_id'].to_s).destroy
    elsif params['component_type'] == 'progress_monitor'
      SimulationProgressMonitor.find_by_id(params['component_id'].to_s).destroy
    end

    flash[:notice] = t('simulations.adapter_destroyed')

    redirect_to :action => :index
  end


  def validate_simulation_input(simulation_input)
    #table for all errors
    error = []

    if simulation_input.kind_of?(Array)
      simulation_input.each do |category|
        if category.kind_of?(Hash)
          category = category.with_indifferent_access
          if category.key?(:label) && !category[:label].kind_of?(String)
            error.push(t('simulations.create.wrong_collection_field_type', field: "Label", collection: "category"))
          end
          if simulation_input.size() >1 && category[:id].blank?
            error.push(t('simulations.create.required_collection_id', collection: "category"))
          end
          if category.key?(:id) && !category[:id].kind_of?(String)
            error.push(t('simulations.create.wrong_collection_field_type', field: "Id", collection: "category"))
          end
          if category[:entities].blank?
            error.push(t('simulations.create.required_collection_key', field: "entities"))
          else
            if category[:entities].kind_of?(Array)
              category[:entities].each do |entity|

                if entity.kind_of?(Hash)
                  if entity.key?(:label) && !entity[:label].kind_of?(String)
                    error.push(t('simulations.create.wrong_collection_field_type', field: "Label", collection: "entity"))
                  end
                  if category[:entities].size() >1 && !entity.key?(:id)
                    error.push(t('simulations.create.required_collection_id', collection: "entity"))
                  end
                  if entity.key?(:id) && !entity[:id].kind_of?(String)
                    error.push(t('simulations.create.wrong_collection_field_type', field: "Id", collection: "entity"))
                  end
                  unless entity.key?(:parameters)
                    error.push(t('simulations.create.required_collection_key', field: "parameters"))
                  end
                  if entity[:parameters].kind_of?(Array)
                    entity[:parameters].each do |parameter|
                      if parameter.kind_of?(Hash)
                        validation_param = validate_simulation_input_parameter(parameter)
                        unless validation_param.blank?
                          error.push(validation_param)
                        end
                      else
                        error.push(t('simulations.create.wrong_collection_type', collection: "parameters"))
                      end
                    end
                  else
                    error.push(t('simulations.create.wrong_groped_collection_type', field: "parameters"))
                  end
                else
                  error.push(t('simulations.create.wrong_collection_type', collection: "entities"))
                end
              end
            else
              error.push(t('simulations.create.wrong_groped_collection_type', field: "entities"))
            end
          end

        else
          error.push(t('simulations.create.wrong_collection_type', collection: "categories"))
        end
      end
    else
      error.push(t('simulations.create.wrong_groped_collection_type', field: "categories"))
    end

    error.join(',')
  end

  def validate_simulation_input_parameter(parameter)
    error =[]
    if parameter.key?(:label) && !parameter[:label].kind_of?(String)
      error.push(t('simulations.create.wrong_collection_field_type', field: "Label", collection: "parameter"))
    end
    if parameter[:id].blank? || !parameter[:id].kind_of?(String)
      error.push(t('simulations.create.required_collection_id', collection: "parameter"))
    end
    if parameter[:type] == 'string'
      allowed_values = parameter[:allowed_values]
      if not allowed_values or not allowed_values.kind_of?(Array) or allowed_values.empty? or
          not allowed_values.all? { |av| av.kind_of?(String) }
        error.push(t('simulations.create.invalid_allowed_values'))
      end
    elsif parameter[:type] == 'integer'

      if parameter[:min].blank?
        error.push(t('simulations.create.parameter_field_not_found', type: "Minimum"))
      else
        unless parameter[:min].integer?
          error.push(t('simulations.create.not_valid_parameter_value', type: "minimum"))
        end
      end

      if parameter[:max].blank?
        error.push(t('simulations.create.parameter_field_not_found', type: "Maximum"))
      else
        unless parameter[:max].integer?
          error.push(t('simulations.create.not_valid_parameter_value', type: "maximum"))
        end
      end

    elsif parameter[:type] =='float'

      if parameter[:min].blank?
        error.push(t('simulations.create.parameter_field_not_found', type: "Minimum"))
      else
        unless parameter[:min].kind_of?(Fixnum) || parameter[:min].kind_of?(Float)
          error.push(t('simulations.create.not_valid_parameter_value', type: "minimum"))
        end
      end
      if parameter[:max].blank?
        error.push(t('simulations.create.parameter_field_not_found', type: "Maximum"))
      else
        unless parameter[:max].kind_of?(Fixnum) || parameter[:min].kind_of?(Float)
          error.push(t('simulations.create.not_valid_parameter_value', type: "maximum"))
        end
      end

    else
      error.push(t('simulations.create.wrong_parameter_type'))
    end
    error
  end

  def create
    simulation_input = Utils.parse_json_if_string(Utils.read_if_file(params[:simulation_input]))
    #temporary to fail all wrong parsing replace with raise Error
    validation_error = validate_simulation_input(simulation_input)
    if validation_error != ""
      raise ValidationError.new('simulation_input', '', validation_error)
    end
    # input validation
    case true
      when (params[:simulation_name].blank?)
        flash[:error] = t('simulations.create.no_simulation_name')

      when (not Simulation.where(user_id: current_user.id, name: params[:simulation_name]).to_a.blank?)
        flash[:error] = t('simulations.create.simulation_invalid_name')

      when (simulation_input.blank?)
        flash[:error] = t('simulations.create.no_simulation_input_description')

      when (params[:simulation_binaries].blank?)
        flash[:error] = t('simulations.create.no_simulation_binaries')
    end

    unless simulation_input.blank?
      unless flash[:error].blank? or (
      begin
        Utils.parse_json_if_string(simulation_input) and true rescue false
      end)
        flash[:error] = t('simulations.create.bad_simulation_input')
      end
    end
    # simulation creation
    if flash[:error].nil?
      simulation = Simulation.new({
                                      'name' => params[:simulation_name],
                                      'description' => params[:simulation_description],
                                      'input_specification' => simulation_input,
                                      'user_id' => current_user.id,
                                      'created_at' => Time.now
                                  })

      begin
        set_up_adapter_checked(simulation, 'input_writer', current_user, params, false)
        set_up_adapter_checked(simulation, 'executor', current_user, params)
        set_up_adapter_checked(simulation, 'output_reader', current_user, params, false)
        set_up_adapter_checked(simulation, 'progress_monitor', current_user, params, false)

        simulation.set_simulation_binaries(params[:simulation_binaries].original_filename, params[:simulation_binaries].read)

        simulation.save
      rescue Exception => e
        flash[:error] = t('simulations.create.internal_error') unless flash[:error]
        Rails.logger.error("Exception occurred when setting up adapters or binaries: #{e}\n#{e.backtrace.join("\n")}")
      end
    end

    flash[:notice] = t('simulations.create.registered') if flash[:error].nil?

    error_occured = (not flash[:error].nil?)

    if error_occured
      Rails.logger.error("An error occured on simulation registering: #{flash[:error]}")
    end

    respond_to do |format|
      format.json do
        render json: {
            status: (error_occured ? 'error' : 'ok'),
            msg: (flash[:error] or 'ok'),
            simulation_id: (simulation.nil? ? nil : simulation.id.to_s)
        }, status: (error_occured ? :internal_server_error : :ok)
      end
      format.html { redirect_to action: :index }
    end
  end

  def destroy_simulation
    sim = Simulation.find_by_id(params['component_id'].to_s)
    flash[:notice] = t('simulations.destroy', name: sim.name)
    sim.destroy

    redirect_to :action => :index
  end

  # following methods are used in experiment conducting
  def conduct_experiment
    @simulation = Simulation.find_by_id(params[:simulation_id].to_s)
    @simulation_input = @simulation.input_specification
  end

  # a life-cycle of a single simulation
  # Expected params:
  #  * execution_statistics (optional) - hash containing information about simulation execution, currently:
  #     * time_in_seconds - float, time of simulation execution in seconds
  def mark_as_complete
    response = {status: 'ok'}
    sm_record = nil
    begin
      Scalarm::MongoLock.mutex("experiment-#{@experiment.id}-simulation-complete") do
        if @simulation_run.nil? or @simulation_run.is_done
          msg = "Simulation run #{params[:id]} of experiment #{params[:experiment_id]} is already done (#{@simulation_run.is_done}) or is nil? (#{@simulation_run.nil?})"

          Rails.logger.error(msg)
          response = {status: 'preconditioned_failed', reason: msg}
        else
          unless sm_user.nil?
            if @simulation_run.sm_uuid != sm_user.sm_uuid
              Rails.logger.warn("SimulationRun is completed be #{sm_user.sm_uuid} but it should be #{@simulation_run.sm_uuid}")
            end
          end

          @simulation_run.is_done = true
          @simulation_run.to_sent = false

          if params[:result].blank?
            @simulation_run.result = {}
          else
            begin
              @simulation_run.result = Utils.parse_json_if_string(params[:result])
            rescue Exception => e
              Rails.logger.warn("Got invalid result for #{@simulation_run.id} simulation:\n#{params[:result].to_s}")
              @simulation_run.result = {}
              @simulation_run.is_error = true
              @simulation_run.error_reason = t('simulations.error.invalid_result_format') + "\n\n" + params[:result].to_s
            end
          end

          if params.include?(:status) and params[:status] == 'error'
            @simulation_run.is_error = true
            @simulation_run.error_reason = params[:reason] if params.include?(:reason)
          end

          @simulation_run.done_at = Time.now
          # infrastructure-related info
          if params.include?('cpu_info')
            cpu_info = Utils.parse_json_if_string(params[:cpu_info])
            @simulation_run.cpu_info = cpu_info
          end

          sm_record = !sm_user.nil? && InfrastructureFacadeFactory.get_sm_records_by_query(sm_uuid: sm_user.sm_uuid).first

          if sm_record
            unless sm_record.infrastructure.blank?
              @simulation_run.infrastructure = sm_record.infrastructure
            end

            unless sm_record.computational_resources.blank?
              @simulation_run.computational_resources = sm_record.computational_resources
            end

            sm_record.simulations_left -= 1 if sm_record.simulations_left
            sm_record.finished_simulations ||= 0
            sm_record.finished_simulations += 1
            sm_record.save

            unless sm_record.has_more_simulations_to_run?
              InfrastructureFacadeFactory.get_facade_for(sm_record.infrastructure)
                  .yield_simulation_manager(sm_record) { |sm| sm.stop }
            end
          end

          if params.include? :execution_statistics
            @simulation_run.execution_statistics = Utils.parse_json_if_string params[:execution_statistics]
          end

          @simulation_run.save
          # TODO adding caching capability
          #@simulation.remove_from_cache

          if params.include?(:status) and params[:status] == 'error'
            @experiment.progress_bar_update(@simulation_run.index, 'error')
          else
            @experiment.progress_bar_update(@simulation_run.index, 'done')
          end
          Thread.new { WorkersScaling::AlgorithmRunner.execute_and_schedule(@experiment.id) }
        end
      end
    rescue Exception => e
      Rails.logger.error("Error in marking a simulation as complete - #{e}")
      response = {status: 'error', reason: e.to_s}
    end

    render json: response
  end

  def progress_info
    response = {status: 'ok'}

    begin
      if @simulation_run.nil? or @simulation_run.is_done
        logger.debug("Simulation #{params[:id]} of experiment #{params[:experiment_id]} is already done or is nil? #{@simulation_run.nil?}")
      else
        @simulation_run.tmp_results_list ||= []
        @simulation_run.tmp_results_list << {time: Time.now, result: Utils.parse_json_if_string(params[:result])}
        @simulation_run.save
      end
    rescue Exception => e
      Rails.logger.debug("Error in the 'progress_info' function - #{e}")
      response = {status: 'error', reason: e.to_s}
    end

    render json: response
  end

  def progress_info_history
    render json: @simulation_run.tmp_results_list
  end

  def show
    information_service = InformationService.instance

    if Rails.application.secrets.include?(:storage_manager_url)
      @storage_manager_url = Rails.application.secrets.storage_manager_url
    else
      @storage_manager_url = information_service.get_list_of('storage_managers')
      @storage_manager_url = @storage_manager_url.sample unless @storage_manager_url.nil?
    end

    if @simulation_run.nil?
      @simulation_run = @experiment.generate_simulation_for(params[:id].to_i)
      @simulation_run.save
    end

    @output_size, @output_size_label, @output_size_err = simulation_output_size
    @stdout_size, @stdout_size_label, @stdout_size_err = simulation_stdout_size

    render partial: 'show'
  end

  def simulation_scenarios
    @simulations = current_user.get_simulation_scenarios.sort { |s1, s2| s2.created_at <=> s1.created_at }

    render partial: 'simulation_scenarios', locals: {show_close_button: true}
  end

  def upload_parameter_space
    i = 0
    parameters = {values: []}
    CSV.parse(params[:file_content]) do |row|
      Rails.logger.debug("row: #{row}")
      if i == 0
        parameters[:columns] = row
      elsif i == 1
        row.each_with_index do |token, index|
          begin
            if Utils.parse_json_if_string(token).kind_of?(Array)
              parameters[:values] << 'Multiple values'
            else
              parameters[:values] << 'Single value'
            end
          rescue Exception => e
            parameters[:values] << 'Single value'
          end
        end
      end
      i += 1
    end

    @simulation = Simulation.find_by_id(params[:simulation_id].to_s)
    @simulation_parameters = @simulation.input_parameters

    render json: {status: 'ok', columns: render_to_string(partial: 'simulations/import/parameter_selection_table', object: parameters)}
  end

  def results_binaries
    storage_manager_url = InformationService.instance.sample_public_url 'storage_managers'
    redirect_to LogBankUtils::simulation_run_binaries_url(storage_manager_url,
                                                          @experiment.id, @simulation_run.index, @current_uer)
  end

  def results_stdout
    storage_manager_url = InformationService.instance.sample_public_url 'storage_managers'
    redirect_to LogBankUtils::simulation_run_stdout_url(storage_manager_url,
                                                        @experiment.id, @simulation_run.index, @current_uer)
  end

  def update
    @msg = {}

    if params.include?(:reset) and params[:reset] and not @simulation_run.nil?

      begin
        @simulation_run.rollback!
      rescue Exception => e
        @msg[:error] = e.to_s
      end

      @msg[:notice] = t("simulations.show.reset_scheduled")
    else
      @msg[:error] = t("simulations.show.reset_not_supported")
    end
  end

  private

  def load_simulation
    @experiment, @simulation_run = nil, nil

    return unless params.include?('id') and params.include?('experiment_id')
    experiment_id = BSON::ObjectId(params[:experiment_id])

    @experiment = if not current_user.nil?
                    current_user.experiments.where(id: experiment_id).first
                  elsif not sm_user.nil?
                    user = sm_user.scalarm_user

                    user.experiments.where(id: experiment_id).first
                  end

    unless @experiment.nil?
      @simulation_run = @experiment.simulation_runs.where(index: params[:id].to_i).first
    end

    if @simulation_run.nil?
      @simulation_run = @experiment.generate_simulation_for(params[:id].to_i)
      @simulation_run.to_sent = true
    end
  end

  def simulation_output_size
    error, output_size = 1, 0

    unless @simulation_run.nil? or @storage_manager_url.blank?
      begin
        url = LogBankUtils::simulation_binaries_size_url(@storage_manager_url,
                                                         @experiment.id,
                                                         @simulation_run.index)
        size_response = RestClient::Request.execute(:url => url, :method => :get, :verify_ssl => false)

        if size_response.code == 200
          output_size = Utils.parse_json_if_string(size_response.body)['size']
          error = 0
        end
      rescue => ex
        Rails.logger.error("An exception occured during communication with Storage Manager")
        Rails.logger.error("Error: #{ex.inspect}")
      end
    end

    return output_size, human_readable_label(output_size), error
  end

  def simulation_stdout_size
    error, output_size = 1, 0

    unless @simulation_run.nil? or @storage_manager_url.blank?
      begin
        url = LogBankUtils::simulation_run_stdout_size_url(@storage_manager_url,
                                                           @experiment.id,
                                                           @simulation_run.index)
        size_response = RestClient::Request.execute(:url => url, :method => :get, :verify_ssl => false)

        if size_response.code == 200
          output_size = Utils.parse_json_if_string(size_response.body)['size']
          error = 0
        end
      rescue => ex
        Rails.logger.error("An exception occured during communication with Storage Manager")
        Rails.logger.error("Error: #{ex.inspect}")
      end
    end

    return output_size, human_readable_label(output_size), error
  end

  def human_readable_label(size)
    if size > 1024
      size /= 1024

      if size > 1024
        size /= 1024
        "#{size} [MB]"
      else
        "#{size} [kB]"
      end

    else
      "#{size} [B]"
    end
  end

end
