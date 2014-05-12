require 'zip'
require 'infrastructure_facades/infrastructure_facade'
require 'csv'


class ExperimentsController < ApplicationController
  before_filter :load_experiment, except: [:index, :share]
  before_filter :load_simulation, only: [ :create, :start_import_based_experiment ]

  def index
    @running_experiments = @current_user.get_running_experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }
    @historical_experiments = @current_user.get_historical_experiments.sort { |e1, e2| e2.end_at <=> e1.end_at }
    @simulations = @current_user.get_simulation_scenarios
  end

  def show
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
    information_service = InformationService.new(config['information_service_url'], 
                                                 config['information_service_user'], 
                                                 config['information_service_pass'])

    @storage_manager_url = information_service.get_list_of('storage')
    @storage_manager_url = @storage_manager_url.sample unless @storage_manager_url.nil?

    begin
      if Time.now - @experiment.start_at > 30
        Thread.new do
          Rails.logger.debug("Updating all progress bars --- #{Time.now - @experiment.start_at}")
          @experiment.update_all_bars
        end
      end

    rescue Exception => e
      flash[:error] = t('experiments.not_found', { id: @experiment.id, user: @current_user.login })
      redirect_to action: :index
    end
  end

  def running_experiments
    @running_experiments = @current_user.get_running_experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }

    render partial: 'running_experiments', locals: { show_close_button: true }
  end

  def historical_experiments
    @historical_experiments = @current_user.get_historical_experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }

    render partial: 'historical_experiments', locals: { show_close_button: true }
  end

  def get_booster_dialog
    # TODO: change to InfrastructuresController.get_booster_dialog with experiment_id set
    render inline: render_to_string(partial: 'booster_dialog')
  end

  # stops the currently running DF experiment (if any)
  def stop
    @experiment.is_running = false
    @experiment.end_at = Time.now

    @experiment.save_and_cache

    SimulationManagerTempPassword.find_all_by_experiment_id(@experiment.id.to_s).each do |tmp_pass|
      tmp_pass.destroy
    end

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.json { render json: { status: 'ok' } }
    end  
  end

  def file_with_configurations
    send_data(@experiment.create_result_csv, type: 'text/plain', filename: "configurations_#{@experiment.id}.txt")
  end

  def create
    doe_info = []
    unless params['doe'].blank?
      doe_info = JSON.parse(params['doe']).delete_if { |doe_id, parameters| parameters.first.nil? } 
    end

    # create the new type of experiment object
    experiment = Experiment.new({ 'simulation_id' => @simulation.id,
      'is_running' => true,
      'replication_level' => params['replication_level'].blank? ? 1 : params['replication_level'].to_i,
      'time_constraint_in_sec' => params['execution_time_constraint'].blank? ? 3600 : params['execution_time_constraint'].to_i * 60,
      'doe_info' => doe_info,
      'start_at' => Time.now,
      'user_id' => @current_user.id,
      'scheduling_policy' => 'monte_carlo'
    })
    experiment.name = params['experiment_name'].blank? ? @simulation.name : params['experiment_name']
    experiment.description = params['experiment_description'].blank? ? @simulation.description : params['experiment_description']
    experiment.experiment_input = Experiment.prepare_experiment_input(
                                    @simulation, JSON.parse(params['experiment_input']), experiment.doe_info)
    experiment.labels = experiment.parameters.flatten.join(',')
    experiment.save
    experiment.experiment_id = experiment.id
    experiment.experiment_size(true)
    experiment.save
    # create progress bar
    experiment.insert_initial_bar
    experiment.create_simulation_table

    if params.include?(:computing_power) and (not params[:computing_power].empty?)
      computing_power = JSON.parse(params[:computing_power])
      InfrastructureFacade.schedule_simulation_managers(@current_user, experiment.id, 
        computing_power['type'], 
        computing_power['resource_counter'])
    end

    respond_to do |format|
      format.html { redirect_to experiment_path(experiment.id) }
      format.json { render json: { status: 'ok', experiment_id: experiment.id.to_s } }
    end    
  end

  def start_import_based_experiment
    parameters_to_include = params.keys.select{ |parameter|
      parameter.start_with?('param_') and params[parameter] == '1'
    }.map{ |parameter| parameter.split('param_').last }

    importer = ExperimentCsvImporter.new(params[:parameter_space_file].read, parameters_to_include)

    are_csv_parameters_not_valid = importer.parameters.any? do |param_uid| 
      not @simulation.input_parameters.include?(param_uid)
    end

    if are_csv_parameters_not_valid
      flash[:error] = t('experiments.import.csv_parameters_not_valid')

      respond_to do |format|
        format.html { redirect_to simulations_path }
        format.json { render json: { status: 'error', msg: flash[:error] } }
      end      
    else
      # create the new type of experiment object
      experiment = Experiment.new({ 'simulation_id' => @simulation.id,
        'is_running' => true,
        'replication_level' => params['replication_level'].blank? ? 1 : params['replication_level'].to_i,
        'time_constraint_in_sec' => params['execution_time_constraint'].blank? ? 3600 : params['execution_time_constraint'].to_i * 60,
        'doe_info' => [ [ 'csv_import', importer.parameters, importer.parameter_values ] ],
        'start_at' => Time.now,
        'user_id' => @current_user.id,
        'scheduling_policy' => 'monte_carlo'
      })
      experiment.name = params['experiment_name'].blank? ? @simulation.name : params['experiment_name']
      experiment.description = params['experiment_description'].blank? ? @simulation.description : params['experiment_description']
      experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)
      experiment.labels = experiment.parameters.flatten.join(',')
      experiment.save
      experiment.experiment_id = experiment.id
      experiment.experiment_size(true)
      experiment.save
      # create progress bar
      experiment.insert_initial_bar
      experiment.create_simulation_table

      respond_to do |format|
        format.html { redirect_to experiment_path(experiment.id) }
        format.json { render json: { status: 'ok', experiment_id: experiment.id.to_s } }
      end
    end
  end

  def calculate_experiment_size
    @simulation = if params['simulation_id']
                    Simulation.find_by_id params['simulation_id']
                  elsif params['simulation_name']
                    Simulation.find_by_name params['simulation_name']
                  else
                    nil
                  end

    doe_info = if params['doe'].blank?
                 []
               else
                 JSON.parse(params['doe']).delete_if { |doe_id, parameter_list| parameter_list.first.nil? }
               end
    @experiment_input = Experiment.prepare_experiment_input(@simulation, JSON.parse(params['experiment_input']), doe_info)

    # create the new type of experiment object
    experiment = Experiment.new({ 'simulation_id' => @simulation.id,
                                 'replication_level' => params['replication_level'].blank? ? 1 : params['replication_level'].to_i,
                                 'experiment_input' => @experiment_input,
                                 'replication_level' => params['replication_level'].blank? ? 1 : params['replication_level'].to_i,
                                 'name' => @simulation.name,
                                 'doe_info' => doe_info
                                })

    experiment_size = experiment.experiment_size(true)
    Rails.logger.debug("Experiment size is #{experiment_size}")

    render json: { experiment_size: experiment_size }
  end

  def calculate_imported_experiment_size
    parameters_to_include = params.keys.select{ |parameter|
      parameter.start_with?('param_') and params[parameter] == '1'
    }.map{ |parameter| parameter.split('param_').last }

    importer = ExperimentCsvImporter.new(params[:file_content], parameters_to_include)
    replication_level = params['replication_level'].blank? ? 1 : params['replication_level'].to_i

    render json: { experiment_size: importer.parameter_values.size * replication_level }
  end

  ### Progress monitoring API

  def completed_simulations_count
    simulation_counter = @experiment.completed_simulations_count_for(params[:secs].to_i)

    render json: {count: simulation_counter}
  end

  def experiment_stats
    sims_generated, sims_sent, sims_done = @experiment.get_statistics

    if sims_generated > @experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations generated for experiment #{@experiment.inspect}")
      sims_generated = @experiment.experiment_size
    end

    if sims_done + sims_sent > @experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations done and sent for experiment #{@experiment.inspect}")
      sims_done = @experiment.experiment_size - sims_sent
    end

    #if sims_generated > @experiment.experiment_size
    #  @experiment.experiment_size = sims_generated
    #  @experiment.save
    #end

    stats = {
        all: @experiment.experiment_size, sent: sims_sent, done_num: sims_done,
        done_percentage: "'%.2f'" % ((sims_done.to_f / @experiment.experiment_size) * 100),
        generated: [sims_generated, @experiment.experiment_size].min,
        progress_bar: "[#{@experiment.progress_bar_color.join(',')}]"
    }

    # TODO - mean execution time and predicted time to finish the experiment
    if sims_done > 0 and (rand() < (sims_done.to_f / @experiment.experiment_size) or sims_done == @experiment.experiment_size)
      execution_time = @experiment.find_simulation_docs_by({is_done: true}, {fields: %w(sent_at done_at)}).reduce(0) do |acc, simulation|
        if simulation.include?('done_at') and simulation.include?('sent_at')
          acc += simulation['done_at'] - simulation['sent_at']
        else
          acc
        end
     end
     stats['avg_execution_time'] = (execution_time / sims_done).round(2)
    
    #  predicted_finish_time = (Time.now - experiment.start_at).to_f / 3600
    #  predicted_finish_time /= (instances_done.to_f / experiment.experiment_size)
    #  predicted_finish_time_h = predicted_finish_time.floor
    #  predicted_finish_time_m = ((predicted_finish_time.to_f - predicted_finish_time_h.to_f)*60).to_i
    #
    #  predicted_finish_time = ''
    #  predicted_finish_time += "#{predicted_finish_time_h} hours"  if predicted_finish_time_h > 0
    #  predicted_finish_time += ' and ' if (predicted_finish_time_h > 0) and (predicted_finish_time_m > 0)
    #  predicted_finish_time +=  "#{predicted_finish_time_m} minutes" if predicted_finish_time_m > 0
    #
    #  partial_stats["predicted_finish_time"] = predicted_finish_time
    end

    render json: stats
  end

  def experiment_moes
    moes_info = {}

    moes = @experiment.result_names
    moes = moes.nil? ? ['No MoEs found', 'nil'] : moes.map { |x| [Experiment.output_parameter_label_for(x), x] }

    done_instance = @experiment.find_simulation_docs_by({'is_done' => true}, {limit: 1, fields: %w(arguments)}).first

    moes_and_params = if done_instance.nil?
                        ['No input parameters found', 'nil']
                      else
                        moes + [%w(----------- nil)] +
                            done_instance['arguments'].split(',').map { |x| [@experiment.input_parameter_label_for(x), x] }
                      end

    moes_info[:moes] = moes.map { |label, id| "<option value='#{id}'>#{label}</option>" }.join()
    moes_info[:moes_and_params] = moes_and_params.map { |label, id| "<option value='#{id}'>#{label}</option>" }.join()

    render json: moes_info
  end

  #  getting parametrization and generated values of every input parameter without default value
  def extension_dialog
    @parameters = {}

    @experiment.parameters.flatten.each do |parameter_uid|
      parameter_doc = @experiment.get_parameter_doc(parameter_uid)
      next if parameter_doc['with_default_value'] # it means this parameter has only one possible value - the default one
      parameter_info = {}
      parameter_info[:label] = @experiment.input_parameter_label_for(parameter_uid)
      parameter_info[:parametrizationType] = parameter_doc['parametrizationType']
      parameter_info[:in_doe] = parameter_doc['in_doe']
      parameter_info[:values] = @experiment.parameter_values_for(parameter_uid)

      @parameters[parameter_uid] = parameter_info
    end

    #Rails.logger.debug("Parameters: #{@parameters}")

    render partial: 'extension_dialog'
  end

  def extend_input_values
    parameter_uid = params[:param_name]
    @range_min, @range_max, @range_step = params[:range_min].to_f, params[:range_max].to_f, params[:range_step].to_f
    Rails.logger.debug("New range values: #{@range_min} --- #{@range_max} --- #{@range_step}")
    new_parameter_values = @range_min.step(@range_max, @range_step).to_a
    #@priority = params[:priority].to_i
    Rails.logger.debug("New parameter values: #{new_parameter_values}")

    @num_of_new_simulations = @experiment.add_parameter_values(parameter_uid, new_parameter_values)
    if @num_of_new_simulations > 0
      @experiment.create_progress_bar_table.drop
      @experiment.insert_initial_bar

      # 4. update progress bar
      Thread.new do
        Rails.logger.debug("Updating all progress bars --- #{Time.now - @experiment.start_at}")
        @experiment.update_all_bars
      end
    end

    File.delete(@experiment.file_with_ids_path) if File.exist?(@experiment.file_with_ids_path)

    respond_to do |format|
      format.js { render partial: 'extend_input_values' }
    end
  end

  def running_simulations_table
  end

  def completed_simulations_table
  end

  def intermediate_results
    unless @experiment.parameters.blank?
      arguments = @experiment.parameters.flatten

      results = if params[:simulations] == 'running'
                  @experiment.find_simulation_docs_by({to_sent: false, is_done: false})
                  #ExperimentInstance.find_by_query(@experiment.experiment_id, {'to_sent' => false, 'is_done' => false})
                elsif params[:simulations] == 'completed'
                  @experiment.find_simulation_docs_by({is_done: true})
                  #ExperimentInstance.find_by_query(@experiment.experiment_id, {'is_done' => true})
                end

      result_column = if params[:simulations] == 'running'
                        'tmp_result'
                      elsif params[:simulations] == 'completed'
                        'result'
                      end

      results = results.map{ |simulation|
        unless simulation.include?('sent_at') and simulation.include?('id') and simulation.include?('values')
          next
        end

        if (params[:simulations] == 'completed') and (not simulation.include?('done_at'))
          next
        end

        split_values = simulation['values'].split(',')
        modified_values = @experiment.range_arguments.reduce([]){|acc, param_uid| acc << split_values[arguments.index(param_uid)]}
        time_column = if params[:simulations] == 'running'
                        simulation['sent_at'].strftime('%Y-%m-%d %H:%M')
                              elsif params[:simulations] == 'completed'
                                "#{simulation['done_at'] - simulation['sent_at']} [s]"
                              end

        [
            simulation['id'],
            time_column,
            simulation[result_column].to_s || 'No data available',
            modified_values
        ].flatten
      }

      render json: { 'aaData' => results }.as_json
    else
      render json: { 'aaData' => [] }.as_json
    end
  end

  def change_scheduling_policy
    new_scheduling_policy = params[:scheduling_policy]

    @experiment.scheduling_policy = new_scheduling_policy
    msg = if @experiment.save_and_cache
      'The scheduling policy of the experiment has been changed.'
    else
      'The scheduling policy of the experiment could not have been changed due to internal server issues.'
    end

    respond_to do |format|
      format.js {
        render :inline => "
          $('#scheduling-busy').hide();
          $('#scheduling-ajax-response').html('#{msg}');
          $('#policy_name').html('#{new_scheduling_policy}');
        "
      }
    end
  end

  def destroy
    unless @experiment.nil?
      @experiment.destroy
      flash[:notice] = 'Your experiment has been destroyed.'
    else
      flash[:notice] = 'Your experiment is no longer available.'
    end

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.json { render json: { status: 'ok' } }
    end  
  end

  # modern version of the next_configuration method;
  # returns a json document with all necessary information to start a simulation
  def next_simulation
    simulation_doc = {}

    begin
      raise 'Experiment is not running any more' if not @experiment.is_running

      simulation_to_send = @experiment.get_next_instance
      Rails.logger.debug("Is simulation nil? #{simulation_to_send}")
      if simulation_to_send
        # TODO adding caching capability to the experiment object
        #simulation_to_send.put_in_cache
        @experiment.progress_bar_update(simulation_to_send['id'].to_i, 'sent')

        simulation_doc.merge!({'status' => 'ok', 'simulation_id' => simulation_to_send['id'],
                   'execution_constraints' => { 'time_contraint_in_sec' => @experiment.time_constraint_in_sec },
                   'input_parameters' => Hash[simulation_to_send['arguments'].split(',').zip(simulation_to_send['values'].split(','))] })
      else
        simulation_doc.merge!({'status' => 'all_sent', 'reason' => 'There is no more simulations'})
      end

    rescue Exception => e
      Rails.logger.debug("Error while preparing next simulation: #{e}")
      simulation_doc.merge!({'status' => 'error', 'reason' => e.to_s})
    end

    render json: simulation_doc
  end

  def code_base
    simulation = @experiment.simulation
    code_base_dir = Dir.mktmpdir('code_base')

    file_list = %w(input_writer executor output_reader progress_monitor)
    file_list.each do |filename|
      unless simulation.send(filename).nil?
        IO.write("#{code_base_dir}/#{filename}", simulation.send(filename).code)
      end
    end
    IO.binwrite("#{code_base_dir}/simulation_binaries.zip", simulation.simulation_binaries)
    file_list << 'simulation_binaries.zip'

    zipfile_name = File.join('/tmp', "experiment_#{@experiment._id}_code_base.zip")

    File.delete(zipfile_name) if File.exist?(zipfile_name)

    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      file_list.each do |filename|
        if File.exist?(File.join(code_base_dir, filename))
          zipfile.add(filename, File.join(code_base_dir, filename))
        end
      end
    end

    FileUtils.rm_rf(code_base_dir)

    send_file zipfile_name, type: 'application/zip'
  end

  def histogram
    @chart = HistogramChart.new(@experiment, params[:moe_name], params[:resolution].to_i)
  end

  def scatter_plot
    @chart = ScatterPlotChart.new(@experiment, params[:x_axis], params[:y_axis])
    @chart.prepare_chart_data
  end

  def regression_tree
    @chart = RegressionTreeChart.new(@experiment, params[:moe_name], Rails.configuration.r_interpreter)
    @chart.prepare_chart_data
  end

  def parameter_values
    @parameter_uid = params[:param_name]

    @parameter_uid, @parametrization_type = @experiment.parametrization_of(@parameter_uid)

    @param_type = {}
    @param_type['type'] = @parametrization_type
    @param_values = @experiment.generated_parameter_values_for(@parameter_uid)
  end

  def simulation_manager
    sm_uuid = SecureRandom.uuid
    # prepare locally code of a simulation manager to upload with a configuration file
    InfrastructureFacade.prepare_configuration_for_simulation_manager(sm_uuid, @current_user.id, @experiment.id.to_s)

    send_file "/tmp/scalarm_simulation_manager_#{sm_uuid}.zip", type: 'application/zip'
  end

  def share
    @experiment, @user = nil, nil

    if params.include?('sharing_with_login') and params.include?('id') and not @current_user.nil?
      experiment_id = BSON::ObjectId(params[:id])

      @experiment = Experiment.find_by_query({ '$and' => [
        { _id: experiment_id },
        { user_id: @current_user.id }
      ]})

      @user = ScalarmUser.find_by_login(params[:sharing_with_login])
    end

    if @experiment.nil? or @user.nil?
      flash[:error] = t('experiments.not_found', { id: params[:id], user: @current_user.login })

      redirect_to action: :index
    else
      sharing_list = @experiment.shared_with
      sharing_list = [ ] if sharing_list.nil?
      if params[:mode] == 'unshare'
        sharing_list.delete_if{|x| x == @user.id}
      else
        sharing_list << @user.id
      end

      @experiment.shared_with = sharing_list
      @experiment.save

      flash[:notice] = t("experiments.sharing.#{params[:mode]}", { user: @user.login })

      redirect_to action: :show, id: @experiment.id.to_s
    end
  end

  private

  def load_experiment
    #Rails.logger.debug("Loading experiment --- #{params.include?('id')} --- #{@current_user.nil?}")
    if params.include?('id') and not @current_user.nil?
      experiment_id = BSON::ObjectId(params[:id])

      @experiment = Experiment.find_by_query({ '$and' => [
        { _id: experiment_id },
        { '$or' => [
          { user_id: @current_user.id },
          { shared_with: { '$in' => [ @current_user.id ] } }
        ]}
      ]})

      if @experiment.nil?
        flash[:error] = t('experiments.not_found', { id: params[:id], user: @current_user.login })

        redirect_to action: :index
      end

    elsif (not @sm_user.nil?)
      if  @sm_user.experiment_id != params['id']
        error_msg = t('security.sim_authorization_error', sm_uuid: @sm_user.sm_uuid, experiment_id: params['id'])
        Rails.logger.error(error_msg)

        render json: { status: 'error', reason: error_msg }, status: 403
      else
        @experiment = Experiment.find_by_query({'_id' => BSON::ObjectId(params['id'])})

        if @experiment.nil?
          error_msg = t('experiment_not_found', experiment_id: params['id'], user: @sm_user.sm_uuid)
          Rails.logger.error(error_msg)

          render json: { status: 'error', reason: error_msg }, status: 404
        end
      end
    end
  end

  def load_simulation
    @simulation = if params['simulation_id']
                    Simulation.find_by_id params['simulation_id']
                  elsif params['simulation_name']
                    Simulation.find_by_name params['simulation_name']
                  else
                    nil
                  end
  end   

end
