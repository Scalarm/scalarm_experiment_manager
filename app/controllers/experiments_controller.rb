require 'csv'
require 'rinruby'
require 'xml'
require 'df_xml_parser'
require 'simulation_partitioner'
require 'scenario_file_parser'
require 'json'

require 'zip/zip'

require "#{Rails.root}/public/scalarm_simulation_manager/information_service"


class ExperimentsController < ApplicationController
  include ActionView::Helpers::JavaScriptHelper
  include Spawn

  def index
    @running_experiments = current_user.get_running_experiments.sort{|e1, e2| e2.start_at <=> e1.start_at}
    @historical_experiments = current_user.get_historical_experiments.sort{|e1, e2| e2.end_at <=> e1.end_at}
    @simulation_scenarios = current_user.get_simulation_scenarios.sort{|s1, s2| s2.created_at <=> s1.created_at}

    render layout: 'foundation_application'
  end

  def start_experiment
    @simulation = if params['simulation_id']
                    Simulation.find_by_id params['simulation_id']
                  elsif
                    params['simulation_name']
                    Simulation.find_by_name params['simulation_name']
                  else
                    nil
                  end

    doe_info = if params.include?('doe')
                 JSON.parse(params['doe']).delete_if{|doe_id, parameter_list| parameter_list.first.nil?}
               else
                 []
               end

    @experiment_input = DataFarmingExperiment.prepare_experiment_input(@simulation, JSON.parse(params['experiment_input']), doe_info)
    # prepare scenario parametrization in the old fashion
    @scenario_parametrization = {}
    @experiment_input.each do |entity_group|
      entity_group['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          parameter_uid = DataFarmingExperiment.parameter_uid(entity_group, entity, parameter)
          @scenario_parametrization[parameter_uid] = parameter['parametrizationType']
        end
      end
    end

    # create the old fashion experiment object
    @experiment = Experiment.new(:is_running => true,
                                 :instance_index => 0,
                                 :run_counter => 1,
                                 :time_constraint_in_sec => 60,
                                 :time_constraint_in_iter => 100,
                                 :experiment_name => @simulation.name,
                                 :parametrization => @scenario_parametrization.map { |k, v| "#{k}=#{v}" }.join(','))

    @experiment.save_and_cache
    # create the new type of experiment object
    data_farming_experiment = DataFarmingExperiment.new({'experiment_id' => @experiment.id,
                                                         'simulation_id' => @simulation.id,
                                                         'experiment_input' => @experiment_input,
                                                         'name' => @simulation.name,
                                                         'is_running' => true,
                                                         'run_counter' => 1,
                                                         'time_constraint_in_sec' => 3600,
                                                         'doe_info' => doe_info,
                                                         'start_at' => Time.now,
                                                         'user_id' => current_user.id,
                                                         'scheduling_policy' => 'monte_carlo'
                                                        })
    data_farming_experiment.user_id = current_user.id unless current_user.nil?
    data_farming_experiment.labels = data_farming_experiment.parameters.flatten.join(',')

    data_farming_experiment.save
    # rewrite all necessary parameters
    @experiment.parameters = data_farming_experiment.parametrization_values
    @experiment.arguments = data_farming_experiment.parametrization_values
    @experiment.doe_groups = ''
    @experiment.experiment_size = data_farming_experiment.experiment_size
    @experiment.is_running = true
    @experiment.start_at = Time.now
    # create progress bar
    data_farming_experiment.insert_initial_bar
    data_farming_experiment.create_simulation_table
    # DEPRECATED
    # create multiple list to fast generete subsequent simulations
    #labels = data_farming_experiment.parameters
    #value_list = data_farming_experiment.value_list
    #multiply_list = data_farming_experiment.multiply_list
    #ExperimentInstanceDb.default_instance.store_experiment_info(@experiment, labels, value_list, multiply_list)
    @experiment.save_and_cache

    if params.include?(:computing_power) and (not params[:computing_power].empty?)
      computing_power = JSON.parse(params[:computing_power])
      InfrastructureFacade.schedule_simulation_managers(current_user, data_farming_experiment.id, computing_power['type'], computing_power['resource_counter'])
    end

    respond_to do |format|
      format.html{ redirect_to monitor_experiment_path(data_farming_experiment.id) }
      format.json{ render :json => { status: 'ok', experiment_id: data_farming_experiment.id } }
    end

  end

  def calculate_experiment_size
    @simulation = if params['simulation_id']
                    Simulation.find_by_id params['simulation_id']
                  elsif
                    params['simulation_name']
                    Simulation.find_by_name params['simulation_name']
                  else
                    nil
                  end
    doe_info = JSON.parse(params['doe']).delete_if{|doe_id, parameter_list| parameter_list.first.nil?}
    @experiment_input = DataFarmingExperiment.prepare_experiment_input(@simulation, JSON.parse(params['experiment_input']), doe_info)

    # create the new type of experiment object
    data_farming_experiment = DataFarmingExperiment.new({'experiment_id' => nil,
                                                         'simulation_id' => @simulation.id,
                                                         'experiment_input' => @experiment_input,
                                                         'name' => @simulation.name,
                                                         'is_running' => true,
                                                         'run_counter' => 1,
                                                         'time_constraint_in_sec' => 3600,
                                                         'doe_info' => doe_info
                                                        })
    experiment_size = data_farming_experiment.value_list.reduce(1){|acc, x| acc * x.size}
    Rails.logger.debug("Experiment size is #{experiment_size}")

    respond_to do |format|
      format.json{ render :json => { experiment_size: "#{experiment_size} " } }
    end
  end

  # finds currently running DF experiment (if any) and displays its progress bar
  def monitor
    #scalarm_config = YAML.load(File.open(File.join(Rails.root, 'config', 'scalarm_experiment_manager.yml')))
    #Rails.logger.debug("Scalarm config: #{scalarm_config}")
    @experiment = DataFarmingExperiment.find_by_id(params[:id])

    #Rails.logger.debug("Storage manager URL: #{scalarm_config['information_service_url']}")
    # TODO TMP due to problem with routing in PLGCloud
    information_service = InformationService.new({'information_service_url' => 'localhost:11300'})
    @storage_manager_url = information_service.get_storage_managers.sample

    @error_flag = false

    if @experiment.nil?

      Rails.logger.debug("We have a fatal error with Experiment #{params[:id]} - it will be destroyed --- #{@experiment.nil?}")

      if @experiment
        @experiment.destroy
        flash[:notice] = 'Your experiment has been destroyed.'
      else
        flash[:notice] = 'Your experiment is no longer available.'
      end

      @error_flag = true
      redirect_to :action => :index

    elsif @experiment.user_id != current_user.id
      flash[:error] = 'Required experiment is not yours'
      @error_flag = true

      redirect_to :action => :index
    else

      begin
        set_monitoring_view_params(@experiment)

        Rails.logger.debug("Updating all progress bars --- #{Time.now - @experiment.start_at}")
        if Time.now - @experiment.start_at > 30
          spawn_block(:method => :thread) do
            @experiment.update_all_bars
          end
        end

      rescue Exception => e
        flash[:error] = "Problem occured during loading experiment info - #{e}"
        @error_flag = true
        @experiment.destroy
        flash[:notice] = 'Your experiment has been destroyed.'
        redirect_to :action => :index
      end

    end

    unless @error_flag
      @running_experiments = current_user.get_running_experiments.sort{|e1, e2| e2.start_at <=> e1.start_at}
      @historical_experiments = current_user.get_historical_experiments.sort{|e1, e2| e2.end_at <=> e1.end_at}
      @simulation_scenarios = current_user.get_simulation_scenarios.sort{|s1, s2| s2.created_at <=> s1.created_at}

      @simulation_managers = {}
      InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
        @simulation_managers[infrastructure_id] = infrastructure_info[:facade].get_running_simulation_managers(current_user)
      end

      @current_user = current_user
      render layout: 'foundation_application', locals: { user: current_user }
    end

  end

  def get_booster_dialog
    @experiment = DataFarmingExperiment.find_by_id(params[:id])

    @simulation_managers, @current_states = {}, {}
    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
      @simulation_managers[infrastructure_id] = infrastructure_info[:facade].get_running_simulation_managers(current_user)
      @current_states[infrastructure_id] = infrastructure_info[:facade].current_state(current_user)
    end

    render inline: render_to_string(partial: 'booster_dialog', locals: { user: current_user })
  end

  # stops the currently running DF experiment (if any)
  def stop
    experiment = DataFarmingExperiment.find_by_id(params[:id])

    if experiment
      experiment.is_running = false
      experiment.end_at = Time.now

      #old_exp = Experiment.find(experiment.experiment_id)
      #old_exp.is_running = false
      #old_exp.end_at = Time.now
      #old_exp.save_and_cache

      experiment.save_and_cache
    else
      flash[:notice] = 'Your experiment is no longer available.'
    end

    redirect_to :action => :index
  end

  def destroy
    df_exp = DataFarmingExperiment.find_by_id(params[:id])

    if df_exp
      df_exp.destroy
      flash[:notice] = 'Your experiment has been destroyed.'
    else
      flash[:notice] = 'Your experiment is no longer available.'
    end

    redirect_to :action => :index
  end

  # returns an id of one running experiment or None if there is no such an experiment
  def get_experiment_id
    experiment_id = ExperimentQueue.enqueue_exp_id

    if experiment_id.nil?
      logger.info(t('no_running_experiment_response'))
      render :inline => 'None', :status => 404
    else
      logger.debug("Next experiment id is #{experiment_id}")

      render :inline => experiment_id.to_s
    end
  end

  # modern version of the next_configuration method;
  # returns a json document with all necessary information to start a simulation
  def next_simulation
    simulation_doc = {}

    begin
      experiment = DataFarmingExperiment.find_by_id(params[:id])
      raise 'Experiment is not running any more' if not experiment.is_running

      Rails.logger.debug("Before getting instance")
      simulation_to_send = experiment.get_next_instance
      Rails.logger.debug("Is simulation nil? #{simulation_to_send}")
      if simulation_to_send
        simulation_to_send.put_in_cache
        experiment.progress_bar_update(simulation_to_send.id.to_i, 'sent')

        simulation_doc.merge!({'status' => 'ok', 'simulation_id' => simulation_to_send.id,
                               'execution_constraints' => { 'time_contraint_in_sec' => experiment.time_constraint_in_sec },
                               'input_parameters' => Hash[simulation_to_send.arguments.split(',').zip(simulation_to_send.values.split(','))] })
      else
        simulation_doc.merge!({'status' => 'all_sent', 'reason' => 'There is no more simulations'})
      end

    rescue Exception => e
      Rails.logger.debug("Error while preparing next simulation: #{e}")
      simulation_doc.merge!({'status' => 'error', 'reason' => e.to_s})
    end

    render :json => simulation_doc
  end

  # NOT USED ANY MORE
  #def update_state
  #  @experiment = Experiment.find_by_id(params[:experiment_id])
  #  @all = ExperimentInstance.count_all(params[:experiment_id])
  #  @done, @sent = ExperimentInstance.get_statistics(params[:experiment_id])
  #
  #  respond_to do |format|
  #    format.js {
  #      render :inline => "if($('#pb_busy:visible').length == 0) {
  #          $('#monitoring_section').html('<%= escape_javascript(render :partial => 'monitoring_section') %>');
  #        }"
  #    }
  #  end
  #end

  def experiment_stats
    experiment = DataFarmingExperiment.find_by_id(params[:id])

    stats = if experiment
        generated, instances_done, instances_sent = experiment.get_statistics
        if generated > experiment.experiment_size
          experiment.experiment_size = generated
          experiment.save
        end

        partial_stats = {
            all: experiment.experiment_size, sent: instances_sent, done_num: instances_done,
            done_percentage: "'%.2f'" % ((instances_done.to_f / experiment.experiment_size) * 100),
            generated: [generated, experiment.experiment_size].min,
            progress_bar: "[#{experiment.progress_bar_color.join(',')}]"
        }

        if instances_done > 0 and (instances_done % 3 == 0 or instances_done == experiment.experiment_size)
          ei_perform_time_avg = ExperimentInstance.get_avg_execution_time_of_ei(experiment.id)
          ei_perform_time_avg_m = (ei_perform_time_avg / 60.to_f).floor
          ei_perform_time_avg_s = (ei_perform_time_avg - ei_perform_time_avg_m*60).to_i

          ei_perform_time_avg = ''
          ei_perform_time_avg += "#{ei_perform_time_avg_m} minutes"  if ei_perform_time_avg_m > 0
          ei_perform_time_avg += ' and ' if (ei_perform_time_avg_m > 0) and (ei_perform_time_avg_s > 0)
          ei_perform_time_avg +=  "#{ei_perform_time_avg_s} seconds" if ei_perform_time_avg_s > 0

          # ei_perform_time_avg = "%.2f" % ei_perform_time_avg
          partial_stats['avg_simulation_time'] = ei_perform_time_avg

          predicted_finish_time = (Time.now - experiment.start_at).to_f / 3600
          predicted_finish_time /= (instances_done.to_f / experiment.experiment_size)
          predicted_finish_time_h = predicted_finish_time.floor
          predicted_finish_time_m = ((predicted_finish_time.to_f - predicted_finish_time_h.to_f)*60).to_i

          predicted_finish_time = ''
          predicted_finish_time += "#{predicted_finish_time_h} hours"  if predicted_finish_time_h > 0
          predicted_finish_time += ' and ' if (predicted_finish_time_h > 0) and (predicted_finish_time_m > 0)
          predicted_finish_time +=  "#{predicted_finish_time_m} minutes" if predicted_finish_time_m > 0

          partial_stats["predicted_finish_time"] = predicted_finish_time
        end

        partial_stats
      else
        { all: 0, sent: 0, done_num: 0, done_percentage: "'0.00'", generated: 0, progress_bar: '[]' }
      end

    render json: stats
  end

  def experiment_moes
    experiment = DataFarmingExperiment.find_by_id(params[:id])
    moes_info = {}
    
    moes = experiment.result_names
    moes = moes.nil? ? ['No MoEs found', 'nil'] : moes.map{|x| [ ParameterForm.moe_label(x), x ]}
    #Rails.logger.debug("Result names: #{moes}")

    done_instance = ExperimentInstance.get_first_done(experiment.experiment_id)
    moes_and_params = if done_instance.nil?
        ['No input parameters found', 'nil']
      else
        moes + [ %w(----------- nil) ] +
        done_instance.arguments.split(',').map{|x| [ experiment.input_parameter_label_for(x), x ]}
      end
    
    moes_info[:moes] = moes.map{|label, id| "<option value='#{id}'>#{label}</option>"}.join()
    moes_info[:moes_and_params] = moes_and_params.map{|label, id| "<option value='#{id}'>#{label}</option>"}.join()

    respond_to do |format|
      format.json{ render :json => moes_info }
    end
  end

  def instance_description
    #ei = ExperimentInstance.find_by_id(params[:instance_id])
    desc = "No instance description"
    #if ei then
    #  desc = ""
    #  arguments = ei.arguments.split(",")
    #  values = ei.values.split(",")
    #  arguments.each_with_index do |arg, index|
    #    desc += "#{arg} = #{values[index]}|"
    #  end
    #  desc += "Status: "
    #  if ei.is_done then
    #    desc += "DONE"
    #  elsif not ei.to_sent then
    #    desc += "PERFORMING"
    #  else
    #    desc += "WAITING"
    #  end
    #end

    respond_to do |format|
      format.js {
        render :inline => "'#{desc}'"
      }
    end
  end

  def download_results
    experiment = Experiment.find(params[:simulation_id])
    archive_name = experiment.data_folder_path.split("/").last

    result = %x[cd #{experiment.data_folder_path}/..; zip -r #{archive_name}.zip #{archive_name}]
    send_file "#{Rails.configuration.eusas_data_path}/#{archive_name}.zip", :type => "application/x-gzip"
  end

  def file_with_configurations
    begin
      experiment = DataFarmingExperiment.find_by_id(params[:id])

      file_path = "/tmp/configurations_#{experiment.id}.txt"
      File.delete(file_path) if File.exist?(file_path)

      File.open(file_path, 'w') do |file|
        file.puts(experiment.create_result_csv)
      end

      send_file(file_path, type: 'text/plain')
    rescue Exception => e
      render inline: "No experiment with the given id - #{e}", status: 404
    end
  end

  def histogram
    @experiment = DataFarmingExperiment.find_by_id(params[:id])

    @chart = HistogramChart.new(@experiment, params[:moe_name], params[:resolution].to_i)
  end

  def scatter_plot
    @experiment = DataFarmingExperiment.find_by_id(params[:id])

    @chart = ScatterPlotChart.new(@experiment, params[:x_axis], params[:y_axis])
    @chart.prepare_chart_data
  end

  def regression_tree
    @experiment = DataFarmingExperiment.find_by_id(params[:id])

    @chart = RegressionTreeChart.new(@experiment, params[:moe_name], Rails.configuration.eusas_rinruby)
    @chart.prepare_chart_data
  end

  # NOT USED ANY MORE
  #def get_parameter_values
  #  @experiment = Experiment.find(params[:experiment_id])
  #
  #  @param_r_id = params[:param_name]
  #  @parameter_uid, @parametrization_type = @experiment.parametrization_of(@param_r_id)
  #
  #  @param_type = {}
  #  @param_type['type'] = @parametrization_type
  #  @param_values = @experiment.generated_parameter_values_for(@param_r_id)
  #end

  def parameter_values
    @experiment = DataFarmingExperiment.find_by_id(params[:id])
    @parameter_uid = params[:param_name]

    @parameter_uid, @parametrization_type = @experiment.parametrization_of(@parameter_uid)

    @param_type = {}
    @param_type['type'] = @parametrization_type
    @param_values = @experiment.generated_parameter_values_for(@parameter_uid)
  end

  def extend_input_values
    @experiment = DataFarmingExperiment.find_by_id(params[:id])
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
      spawn_block(:method => :thread) do
        @experiment.update_all_bars
      end
    end

  end

  def change_scheduling_policy
    experiment = DataFarmingExperiment.find_by_id(params[:experiment_id])
    new_scheduling_policy = params[:scheduling_policy]

    experiment.scheduling_policy = new_scheduling_policy
    msg = if experiment.save_and_cache
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

  def latest_running_experiment
    #experiment = get_latest_running_experiment
    #
    #if experiment
    #  redirect_to monitor_experiment_path(experiment.id)
    #else
      redirect_to action: :index
    #end
  end

  def completed_simulations_count
    experiment = DataFarmingExperiment.find_by_id(params[:id])

    simulation_counter = if experiment
                experiment.completed_simulations_count_for(params[:secs].to_i)
              else
                0
              end

    render json: { count: simulation_counter }
  end

  def code_base
    simulation = DataFarmingExperiment.find_by_id(params[:id]).simulation
    code_base_dir = Dir.mktmpdir('code_base')

    file_list = %w(input_writer executor output_reader progress_monitor)
    file_list.each do |filename|
      unless simulation.send(filename).nil?
        IO.write("#{code_base_dir}/#{filename}", simulation.send(filename).code)
      end
    end
    IO.binwrite("#{code_base_dir}/simulation_binaries.zip", simulation.simulation_binaries)
    file_list << 'simulation_binaries.zip'

    zipfile_name = File.join('/tmp', "experiment_#{params[:id]}_code_base.zip")

    File.delete(zipfile_name) if File.exist?(zipfile_name)

    Zip::ZipFile.open(zipfile_name, Zip::ZipFile::CREATE) do |zipfile|
      file_list.each do |filename|
        if File.exist?(File.join(code_base_dir, filename))
          zipfile.add(filename, File.join(code_base_dir, filename))
        end
      end
    end

    FileUtils.rm_rf(code_base_dir)

    send_file zipfile_name, :type => 'application/zip'
  end

  def intermediate_results
    dfe = DataFarmingExperiment.find_by_id(params[:id])
    range_arguments = dfe.range_arguments
    unless dfe.argument_names.nil?
      arguments = dfe.argument_names.split(',')

      results = if params[:simulations] == 'running'
                  ExperimentInstance.find_by_query(dfe.experiment_id, {'to_sent' => false, 'is_done' => false})
                elsif params[:simulations] == 'completed'
                  ExperimentInstance.find_by_query(dfe.experiment_id, {'is_done' => true})
                end

      result_column = if params[:simulations] == 'running'
                        'tmp_result'
                      elsif params[:simulations] == 'completed'
                        'result'
                      end

      results = results.map{ |simulation|
        split_values = simulation['values'].split(',')
        modified_values = range_arguments.reduce([]){|acc, param_uid| acc << split_values[arguments.index(param_uid)]}
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


  def running_simulations_table
    @data_farming_experiment = DataFarmingExperiment.find_by_id(params[:id])
  end

  def completed_simulations_table
    @data_farming_experiment = DataFarmingExperiment.find_by_id(params[:id])
  end

  def extension_dialog
  #  getting parametrization and generated values of every input parameter without default value
    @experiment = DataFarmingExperiment.find_by_id(params[:id])
    @parameters = {}

    @experiment.argument_names.split(',').each do |parameter_uid|
      parameter_doc = @experiment.get_parameter_doc(parameter_uid)
      next if parameter_doc['with_default_value'] # it means this parameter has only one possible value - the default one
      parameter_info = {}
      parameter_info[:label] = @experiment.input_parameter_label_for(parameter_uid)
      parameter_info[:parametrizationType] = parameter_doc['parametrizationType']
      parameter_info[:in_doe] = parameter_doc['in_doe']
      parameter_info[:values] = @experiment.parameter_values_for(parameter_uid)

      @parameters[parameter_uid] = parameter_info
    end

    render partial: 'extension_dialog'
  end

  private

  def select_params_for_parameters_and_doe_groups
    params_to_override = params.select { |key, value| key.starts_with? "Agent" } 
    params_groups_for_doe = params.select { |key, value| key.starts_with?("doe_") and key.ends_with?("_params") }
    
    return params_to_override, params_groups_for_doe
  end

  def set_monitoring_view_params(experiment)
    @all, @done, @sent = experiment.get_statistics
    @parts_per_slot, @number_of_bars = experiment.basic_progress_bar_info
    Rails.logger.debug("EXP id: #{experiment.experiment_id} --- Generated: #{@all} --- Done: #{@done}\
    --- Sent: #{@sent} --- Parts: #{@parts_per_slot} --- Bars: #{@number_of_bars}")

    @bar_colors = experiment.progress_bar_color

    if @done > 0 then
      @ei_perform_time_avg = ExperimentInstance.get_avg_execution_time_of_ei(experiment.experiment_id)
      @ei_perform_time_avg = "%.2f" % @ei_perform_time_avg
    else
      @ei_perform_time_avg = 'Not available yet'
    end

    if @done < 20 then
      @predicted_finish_time = 'Not available yet'
    else
      @predicted_finish_time = (Time.now - experiment.start_at).to_f / 3600
      @predicted_finish_time /= (@done.to_f / experiment.experiment_size)

      @predicted_finish_time = "%.2f" % @predicted_finish_time
    end
  end

end
