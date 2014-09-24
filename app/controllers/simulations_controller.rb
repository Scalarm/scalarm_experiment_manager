require 'json'
require 'simulation'
require 'csv'
require 'rest_client'

class SimulationsController < ApplicationController
  before_filter :load_simulation, only: [:show, :progress_info, :mark_as_complete]

  def index
    @simulations = @current_user.get_simulation_scenarios
    @simulation_scenarios = @simulations
    @input_writers = SimulationInputWriter.find_all_by_user_id(@current_user.id)
    @executors = SimulationExecutor.find_all_by_user_id(@current_user.id)
    @output_readers = SimulationOutputReader.find_all_by_user_id(@current_user.id)
    @progress_monitors = SimulationProgressMonitor.find_all_by_user_id(@current_user.id)
  end

  def registration
    @input_writers = SimulationInputWriter.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}
    @executors = SimulationExecutor.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}
    @output_readers = SimulationOutputReader.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}
    @progress_monitors = SimulationProgressMonitor.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}
  end

  def upload_component
    if params['component_type'] == 'input_writer'
      input_writer = SimulationInputWriter.new({name: params['component_name'], code: Utils.read_if_file(params['component_code']), user_id: @current_user.id})
      input_writer.save
    elsif params['component_type'] == 'executor'
      executor = SimulationExecutor.new({name: params['component_name'], code: Utils.read_if_file(params['component_code']), user_id: @current_user.id})
      executor.save
    elsif params['component_type'] == 'output_reader'
      output_reader = SimulationOutputReader.new({name: params['component_name'], code: Utils.read_if_file(params['component_code']), user_id: @current_user.id})
      output_reader.save
    elsif params['component_type'] == 'progress_monitor'
      progress_monitor = SimulationProgressMonitor.new({name: params['component_name'], code: Utils.read_if_file(params['component_code']), user_id: @current_user.id})
      progress_monitor.save
    end

    flash[:notice] = t('new_adapter_added')

    redirect_to :action => :index
  end

  def destroy_component
    if params['component_type'] == 'input_writer'
      SimulationInputWriter.find_by_id(params['component_id']).destroy
    elsif params['component_type'] == 'executor'
      SimulationExecutor.find_by_id(params['component_id']).destroy
    elsif params['component_type'] == 'output_reader'
      SimulationOutputReader.find_by_id(params['component_id']).destroy
    elsif params['component_type'] == 'progress_monitor'
      SimulationProgressMonitor.find_by_id(params['component_id']).destroy
    end

    flash[:notice] = t('simulations.adapter_destroyed')

    redirect_to :action => :index
  end

  def create
    simulation_input = Utils.parse_json_if_string(Utils.read_if_file(params[:simulation_input]))
    # input validation
    case true
      when (params[:simulation_name].blank? or simulation_input.blank? or params[:simulation_binaries].blank?)
        flash[:error] = t('simulations.create.bad_params')

      when (not Simulation.where(name: params[:simulation_name], user_id: @current_user.id).to_a.blank?)
        flash[:error] = t('simulations.create.simulation_invalid_name')

    end

    unless flash[:error].blank? or (begin Utils.parse_json_if_string(simulation_input) and true rescue false end)
      flash[:error] = t('simulations.create.bad_simulation_input')
    end
    # simulation creation
    if flash[:error].nil?
      simulation = Simulation.new({
        'name' => params[:simulation_name],
        'description' => params[:simulation_description],
        'input_specification' => simulation_input,
        'user_id' => @current_user.id,
        'created_at' => Time.now
      })

      begin
        set_up_adapter('input_writer', simulation, false)
        set_up_adapter('executor', simulation)
        set_up_adapter('output_reader', simulation, false)
        set_up_adapter('progress_monitor', simulation, false)

        simulation.set_simulation_binaries(params[:simulation_binaries].original_filename, params[:simulation_binaries].read)

        simulation.save
      rescue Exception => e
        Rails.logger.error("Exception occurred : #{e}")
      end
    end

    flash[:notice] = t('simulations.create.registered') if flash[:error].nil?

    respond_to do |format|
      format.json { render json: {
          status: (flash[:error].nil? ? 'ok' : 'error'),
          msg: (flash[:error] or 'ok'),
          simulation_id: simulation.id.to_s
      }
      }
      format.html { redirect_to action: :index }
    end
  end

  def destroy_simulation
    sim = Simulation.find_by_id(params['component_id'])
    flash[:notice] = t('simulations.destroy', name: sim.name)
    sim.destroy

    redirect_to :action => :index
  end

  # following methods are used in experiment conducting
  def conduct_experiment
    @simulation = Simulation.find_by_id(params[:simulation_id])
    @simulation_input = @simulation.input_specification
  end

  # a life-cycle of a single simulation
  def mark_as_complete
    response = { status: 'ok' }

    begin
      Scalarm::MongoLock.mutex("experiment-#{@experiment.id}-simulation-complete") do
        if @simulation_run.nil? or @simulation_run.is_done
          msg = "Simulation run #{params[:id]} of experiment #{params[:experiment_id]} is already done or is nil? #{@simulation_run.nil?}"

          Rails.logger.error(msg)
          response = { status: 'error', reason: msg }
        else
          unless @sm_user.nil?
            if @simulation_run.sm_uuid != @sm_user.sm_uuid
              Rails.logger.warn("SimulationRun is completed be #{@sm_user.sm_uuid} but it should be #{@simulation_run.sm_uuid}")
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
              @simulation_run.result = {}
              @simulation_run.is_error = true
              @simulation_run.error_reason = t('simulations.error.invalid_result_format')
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

          unless @sm_user.nil? or (sm_record = @sm_user.simulation_manager_record).nil?
            unless sm_record.infrastructure.blank?
              @simulation_run.infrastructure = sm_record.infrastructure
            end

            unless sm_record.computational_resources.blank?
              @simulation_run.computational_resources = sm_record.computational_resources
            end
          end

          @simulation_run.save
          # TODO adding caching capability
          #@simulation.remove_from_cache

          if params.include?(:status) and params[:status] == 'error'
            @experiment.progress_bar_update(@simulation_run.index, 'error')
          else
            @experiment.progress_bar_update(@simulation_run.index, 'done')
          end
        end
      end
    rescue Exception => e
      Rails.logger.error("Error in marking a simulation as complete - #{e}")
      response = { status: 'error', reason: e.to_s }
    end

    render json: response
  end

  def progress_info
    response = { status: 'ok' }

    begin
      if @simulation_run.nil? or @simulation_run.is_done
        logger.debug("Simulation #{params[:id]} of experiment #{params[:experiment_id]} is already done or is nil? #{@simulation_run.nil?}")
      else
        @simulation_run.tmp_result = Utils.parse_json_if_string(params[:result])
        @simulation_run.save
      end
    rescue Exception => e
      Rails.logger.debug("Error in the 'progress_info' function - #{e}")
      response = { status: 'error', reason: e.to_s }
    end

    render json: response
  end

  def show
    information_service = InformationService.new

    if Rails.application.secrets.include?(:storage_manager_url)
      @storage_manager_url = Rails.application.secrets.storage_manager_url
    else
      @storage_manager_url = information_service.get_list_of('storage_managers')
      @storage_manager_url = @storage_manager_url.sample unless @storage_manager_url.nil?
    end

    @remote_storage_manager_url = information_service.get_list_of('storage_managers')
    @remote_storage_manager_url = @remote_storage_manager_url.sample unless @remote_storage_manager_url.nil?

    if @simulation_run.nil?
      @simulation_run = @experiment.generate_simulation_for(params[:id].to_i)
      Rails.logger.debug("simulation_run: #{@simulation_run.inspect}")
      @simulation_run.save
    end

    @output_size, @output_size_label, @output_size_err = simulation_output_size
    @stdout_size, @stdout_size_label, @stdout_size_err = simulation_stdout_size

    render partial: 'show'
  end

  def simulation_scenarios
    @simulations = @current_user.get_simulation_scenarios.sort { |s1, s2| s2.created_at <=> s1.created_at }

    render partial: 'simulation_scenarios', locals: { show_close_button: true }
  end

  def upload_parameter_space
    i = 0
    parameters = { values: [] }
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

    @simulation = Simulation.find_by_id(params[:simulation_id])
    @simulation_parameters = @simulation.input_parameters

    render json: { status: 'ok', columns: render_to_string(partial: 'simulations/import/parameter_selection_table', object: parameters) }
  end

  private

  def load_simulation
    @experiment, @simulation_run = nil, nil

    return unless params.include?('id') and params.include?('experiment_id')
    experiment_id = BSON::ObjectId(params[:experiment_id])
    Rails.logger.debug("Experiment id : #{experiment_id}")

    @experiment = if not @current_user.nil?
                    @current_user.experiments.where(id: experiment_id).first
                  elsif not @sm_user.nil?
                    user = @sm_user.scalarm_user

                    user.experiments.where(id: experiment_id).first
                  end

    unless @experiment.nil?
      @simulation_run = @experiment.simulation_runs.where(index: params[:id].to_i).first
    end

    Rails.logger.info("Experiment is nil ? #{@experiment.nil?} #{@experiment.nil? ? '' : @experiment.id}")
    Rails.logger.info("SimulationRun is nil ? #{@simulation_run.nil?} #{@simulation_run.nil? ? '' : @simulation_run.inspect}")

    if @simulation_run.nil?
      @simulation_run = @experiment.generate_simulation_for(params[:id].to_i)
      @simulation_run.to_sent = false
      @simulation_run.sent_at = Time.now
    end

  end

  def set_up_adapter(adapter_type, simulation, mandatory = true)

    if params.include?(adapter_type + '_id')
      adapter_id = params[adapter_type + '_id']
      adapter = Object.const_get("Simulation#{adapter_type.camelize}").find_by_id(adapter_id)

      if not adapter.nil? and adapter.user_id == @current_user.id
        simulation.send(adapter_type + '_id=', adapter.id)
      else
        if mandatory
          flash[:error] = t('simulations.create.adapter_not_found', { adapter: adapter_type.camelize, id: adapter_id })
          raise Exception.new("Setting up Simulation#{adapter_type.camelize} is mandatory")
        end
      end

    elsif params.include?(adapter_type)
      adapter_name = if params["#{adapter_type}_name"].blank?
                       params[adapter_type].original_filename
                     else
                       params["#{adapter_type}_name"]
                     end

      adapter = Object.const_get("Simulation#{adapter_type.camelize}").new({
                                           name: adapter_name,
                                           code: Utils.read_if_file(params[adapter_type]),
                                           user_id: @current_user.id})
      adapter.save
      Rails.logger.debug(adapter)
      simulation.send(adapter_type + '_id=', adapter.id)
    else
      if mandatory
        flash[:error] = t('simulations.create.mandatory_adapter', { adapter: adapter_type.camelize, id: adapter_id })
        raise Exception("Setting up Simulation#{adapter_type.camelize} is mandatory")
      end
    end

  end

  def simulation_output_size
    error, output_size = 1, 0

    unless @simulation_run.nil? or @storage_manager_url.blank?
      begin
        size_response = RestClient.get log_bank_simulation_binaries_size_url(@storage_manager_url, @experiment, @simulation_run.index)

        if size_response.code == 200
          output_size = Utils.parse_json_if_string(size_response.body)['size']
          error = 0
        end
      rescue Exception => ex
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
        size_response = RestClient.get log_bank_simulation_stdout_size_url(@storage_manager_url, @experiment, @simulation_run.index)

        if size_response.code == 200
          output_size = Utils.parse_json_if_string(size_response.body)['size']
          error = 0
        end
      rescue Exception => ex
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

  def log_bank_url(storage_manager_url, experiment)
    "https://#{storage_manager_url}/experiments/#{experiment.id}"
  end

  def log_bank_experiment_size_url(storage_manager_url, experiment)
    "#{log_bank_url(storage_manager_url, experiment)}/size"
  end

  def log_bank_simulation_binaries_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_url(storage_manager_url, experiment)}/simulations/#{simulation_id}"
  end

  def log_bank_simulation_binaries_size_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_simulation_binaries_url(storage_manager_url, experiment, simulation_id)}/size"
  end

  def log_bank_simulation_stdout_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_simulation_binaries_url(storage_manager_url, experiment, simulation_id)}/stdout"
  end

  def log_bank_simulation_stdout_size_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_simulation_stdout_url(storage_manager_url, experiment, simulation_id)}_size"
  end

end
