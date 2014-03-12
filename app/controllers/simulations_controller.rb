require 'json'
require 'simulation'

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
      input_writer = SimulationInputWriter.new({name: params['component_name'], code: params['component_code'].read, user_id: @current_user.id})
      input_writer.save
    elsif params['component_type'] == 'executor'
      executor = SimulationExecutor.new({name: params['component_name'], code: params['component_code'].read, user_id: @current_user.id})
      executor.save
    elsif params['component_type'] == 'output_reader'
      output_reader = SimulationOutputReader.new({name: params['component_name'], code: params['component_code'].read, user_id: @current_user.id})
      output_reader.save
    elsif params['component_type'] == 'progress_monitor'
      progress_monitor = SimulationProgressMonitor.new({name: params['component_name'], code: params['component_code'].read, user_id: @current_user.id})
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

  def upload_simulation
    simulation = Simulation.new({
      'name' => params['simulation_name'],
      'description' => params['simulation_description'],
      'input_specification' => params['simulation_input'].read,
      'user_id' => @current_user.id,
      'created_at' => Time.now
    })

    begin
      set_up_adapter('input_writer', simulation, false)
      set_up_adapter('executor', simulation, false)
      set_up_adapter('output_reader', simulation, false)

      set_up_adapter('progress_monitor', simulation, false)

      simulation.set_simulation_binaries(params['simulation_binaries'].original_filename, params['simulation_binaries'].read)

      simulation.save
    rescue Exception => e
      Rails.logger.error("Exception occurred: #{e}")
    end

    respond_to do |format|
      format.json { render json: { status: (flash[:error].nil? ? 'ok' : 'error'), simulation_id: simulation.id.to_s } }
      format.html { redirect_to :action => :index }
    end
  end

  def destroy_simulation
    Simulation.find_by_id(params['component_id']).destroy
    redirect_to :action => :index
  end

  # following methods are used in experiment conducting

  def conduct_experiment
    @simulation = Simulation.find_by_id(params[:simulation_id])
    @simulation_input = JSON.parse(@simulation.input_specification)
  end

  # a life-cycle of a single simulation

  def mark_as_complete
    response = { status: 'ok' }

    begin
      if @simulation.nil? or @simulation['is_done']
        logger.debug("Experiment Instance #{params[:id]} of experiment #{params[:experiment_id]} is already done or is nil? #{@simulation.nil?}")
      else
        @simulation['is_done'] = true
        @simulation['to_sent'] = false
        @simulation['result'] = JSON.parse(params[:result])
        @simulation['done_at'] = Time.now
        @experiment.save_simulation(@simulation)
        # TODO adding caching capability
        #@simulation.remove_from_cache

        @experiment.progress_bar_update(@simulation['id'], 'done')
      end
    rescue Exception => e
      Rails.logger.error("Error in marking a simulation as complete - #{e}")
      response = { status: 'error', reason: e.to_s }
    end

    render :json => response
  end

  def progress_info
    response = {status: 'ok'}

    begin
      if @simulation.nil? or @simulation['is_done']
        logger.debug("Simulation #{params[:id]} of experiment #{params[:experiment_id]} is already done or is nil? #{@simulation.nil?}")
      else
        @simulation['tmp_result'] = JSON.parse(params[:result])
        @experiment.save_simulation(@simulation)
      end
    rescue Exception => e
      Rails.logger.debug("Error in the 'progress_info' function - #{e}")
      response = {status: 'error', reason: e.to_s}
    end

    render :json => response
  end

  def show
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
    information_service = InformationService.new(config['information_service_url'],
                                                 config['information_service_user'],
                                                 config['information_service_pass'])

    @storage_manager_url = information_service.get_list_of('storage')
    @storage_manager_url = @storage_manager_url.sample unless @storage_manager_url.nil?

    if @simulation.nil?
      @simulation = @experiment.generate_simulation_for(params[:id].to_i)
      @experiment.save_simulation(@simulation)
    end

    render partial: 'show'
  end

  def simulation_scenarios
    @simulations = @current_user.get_simulation_scenarios.sort { |s1, s2| s2.created_at <=> s1.created_at }

    render partial: 'simulation_scenarios', locals: { show_close_button: true }
  end

  require 'csv'
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
            if JSON.parse(token).kind_of?(Array)
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
    @experiment = Experiment.find_by_id(params[:experiment_id])
    #Rails.logger.debug("Experiment: #{@experiment}")
    @simulation = @experiment.find_simulation_docs_by({id: params[:id].to_i}, {limit: 1}).first
    #Rails.logger.debug("Simulation: #{@simulation}")
  end

  def set_up_adapter(adapter_type, simulation, mandatory = true)

    if params.include?(adapter_type + '_id')
      adapter_id = params[adapter_type + '_id']
      adapter = Object.const_get("Simulation#{adapter_type.camelize}").find_by_id(adapter_id)

      if not adapter.nil? and adapter.user_id == @current_user.id
        simulation.send(adapter_type + '_id=', adapter.id)
      else
        flash[:error] = "Cannot find Simulation#{adapter_type.camelize} with the #{adapter_id} id"
        raise Exception.new("Setting up Simulation#{adapter_type.camelize} is mandatory") if mandatory
      end

    elsif params.include?(adapter_type)
      adapter = Object.const_get("Simulation#{adapter_type.camelize}").new({name: params[adapter_type].original_filename,
                                           code: params[adapter_type].read,
                                           user_id: @current_user.id})
      adapter.save
      Rails.logger.debug(adapter)
      simulation.send(adapter_type + '_id=', adapter.id)
    else
      #raise Exception("Setting up Simulation#{adapter_type.camelize} is mandatory") if mandatory
    end

  end

end
