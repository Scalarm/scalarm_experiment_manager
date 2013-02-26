require "rubygems"
require "csv"
require "rinruby"
require "xml"
require "df_xml_parser"
require "simulation_partitioner"
require "scenario_file_parser"
require "json"

require 'zip/zip'


class ExperimentsController < ApplicationController
  include ActionView::Helpers::JavaScriptHelper

  def index
    experiment = get_latest_running_experiment

    if experiment and flash[:error].nil?
      redirect_to :action => "monitor", :experiment_id => experiment.id
    else
      @ids, @dones, @experiment_info = Experiment.experiments_info("is_running=1 ORDER BY id DESC")

      @historical_ids, @historical_dones, @historical_exp_info = Experiment.experiments_info(
          "is_running=0 AND start_at IS NOT NULL ORDER BY end_at DESC")

      @simulations = []
      scenario_dir = Rails.configuration.scenarios_path
      Dir.open(scenario_dir).each do |element|
        potential_scenario_file = File.join(scenario_dir, element)
        if File.file?(potential_scenario_file) and element.ends_with?(".xml") then
          @simulations << element
        end
      end

      @simulations.sort!
    end
  end

  # prepare data for a view with definition of types of experiment parameters
  def define_param_types
    prepare_agent_elements
  end

  # preparing data for parametrization of experiment variables
  #TODO FIXME refactor to be one screen height
  def define_input
    prepare_agent_elements
    @scenario_parametrization = {}

    @agent_elements.each do |element|
      element.parameters.each do |param|
        @scenario_parametrization[param.parameter_uid] = params[param.parameter_uid]
      end
    end

    data_farming_scenario = DataFarmingScenario.new(params[:scenario_id], @agent_elements, @scenario_parametrization)
    @document = data_farming_scenario.scenario_xml

    @experiment = Experiment.new(:is_running => false,
                                 :instance_index => 0,
                                 :run_counter => params[:exp_run_counter].to_i,
                                 :time_constraint_in_sec => params[:exp_time_constraint_in_sec].to_i * 60,
                                 :time_constraint_in_iter => params[:exp_time_constraint_in_iter].to_i,
                                 :experiment_name => params[:scenario_id].split(".xml")[0],
                                 :user_id => session[:user],
                                 :parametrization => @scenario_parametrization.map { |k, v| "#{k}=#{v}" }.join(","))

    @experiment.save_and_cache
    @experiment.experiment_file = "Experiment_#{@experiment.id}.xml"

    @experiment.make_simulation_logs_dir

    @document.save(@experiment.experiment_file_path, :indent => true, :encoding => XML::Encoding::UTF_8)

    @parameters = parse_df_scenario(@experiment.experiment_file_path, Rails.configuration.eusas_rinruby)
    @parameters_by_subject_id = @parameters.group_by { |p| p.subject_id }

    @experiment.save_and_cache
  end

  def define_doe
    @experiment = Experiment.find(params[:experiment_id])
    @params_for_doe = []
    @experiment_params = {}

    params.each do |key, value|
      if key.start_with?("Agent") or key.start_with?("Group") then
        @experiment_params[key] = value
      end

      if key.start_with?("Agent") and key.ends_with?("step") then
        reference = key.split("_")[0..-2].join("_")
        @params_for_doe << [ParameterForm.parameter_label_with_agent_id(reference), reference]
      end
    end

  end

  def add_doe_group
    @type = params[:type]
  end

  #TODO FIXME refactor to be one screen height
  def start
    @experiment = Experiment.find_by_id(params[:experiment_id])

    if not @experiment.nil? and not @experiment.is_running then
      params_to_override, params_groups_for_doe = select_params_for_parameters_and_doe_groups
      @experiment.parameters = params_to_override.map{|k,v| "#{k}=#{v}"}.join("|")
      @experiment.doe_groups = params_groups_for_doe.map{|k,v| "#{k}=#{v}"}.join("|")
      
      logger.debug("params_to_override = #{@experiment.parameters}")
      logger.debug("params_groups_for_doe = #{@experiment.doe_groups}")

      @parameters, @doe_groups = @experiment.create_parameters_and_doe_groups
      Rails.logger.debug("Start: after create_parameters_and_doe_groups")

      params_to_override = params.select { |key, value| key.starts_with? "Agent" }
      @experiment.arguments = params_to_override.reduce("") { |acc, item| acc += "#{item[0]}=#{item[1]}|" }.chop

      @experiment.experiment_size = compute_experiment_size(@parameters, @doe_groups) * @experiment.run_counter

      @experiment.make_simulation_logs_dir
      @experiment.is_running = true
      @experiment.start_at = Time.now
      @experiment.save_and_cache

      @experiment.create_progress_bar
      @experiment.generate_instance_configurations

      ExperimentWatcher.watch(@experiment)
    else
      flash["error"] = "No experiment with the given ID"
    end

    redirect_to :action => :monitor, :experiment_id => params[:experiment_id]
  end

  # sets an experiment to the "running" state
  # and create a directory for the simulation logs
  def run
    experiment = Experiment.find_by_id(params[:experiment_id])
    experiment.is_running = true
    experiment.start_at = Time.now
    experiment.save_and_cache
    experiment.make_simulation_logs_dir

    redirect_to :action => :monitor
  end

  # finds currently running DF experiment (if any) and displays its progress bar
  def monitor
    begin
      @experiment = Experiment.find(params[:experiment_id])
      set_monitoring_view_params(params[:experiment_id])

      # Experiments info
      # TODO FIXME move this to background
      @ids, @dones, @experiment_info = Experiment.experiments_info("is_running=1 ORDER BY id DESC")
      @historical_ids, @historical_dones, @historical_exp_info = Experiment.experiments_info(
          "is_running=0 AND start_at IS NOT NULL ORDER BY end_at DESC")

      @simulations = []
      scenario_dir = Rails.configuration.scenarios_path
      Dir.open(scenario_dir).each do |element|
        potential_scenario_file = File.join(scenario_dir, element)
        if File.file?(potential_scenario_file) and element.ends_with?(".xml") then
          @simulations << element
        end
      end
      
      @simulations.sort!

      Rails.logger.debug("Updating all progress bars --- #{Time.now - @experiment.start_at}")
      if Time.now - @experiment.start_at > 30
        spawn(:method => :thread) do
          @experiment.experiment_progress_bar.update_all_bars
        end
      end

    rescue Exception => e
      flash[:error] = "Problem occured during loading experiment info - #{e}"
      logger.debug(e.backtrace)
      redirect_to :action => :index
    end
  end

  # stops the currently running DF experiment (if any)
  def stop
    experiment = Experiment.find(params[:experiment_id])
    if experiment then
      experiment.is_running = false
      experiment.end_at = Time.now
      experiment.save_and_cache
    else
      flash[:notice] = "Your experiment is no longer available."
    end

    redirect_to :action => :index
  end

  def destroy
    experiment = Experiment.find(params[:experiment_id].to_i)

    if experiment
      experiment.experiment_progress_bar.drop
      experiment.experiment_progress_bar.destroy
      spawn do
        ExperimentInstance.drop_instances_for(experiment.id)
        logger.debug(%x[rm -rf #{experiment.data_folder_path}])
      end
      experiment.destroy

      flash[:notice] = "Your experiment has been destroyed."
    else
      flash[:notice] = "Your experiment is no longer available."
    end

    redirect_to :action => :index
  end

  # returns an id of one running experiment or None if there is no such an experiment
  def get_experiment_id
    experiment_id = ExperimentQueue.enqueue_exp_id

    if experiment_id.nil?
      logger.info("No experiment running")
      render :inline => "None", :status => 404
    else
      logger.debug("Next experiment id is #{experiment_id}")
      #experiment = Experiment.find_by_id(exp_id)
      #experiment.vm_counter += 1
      #experiment.save
      #
      #Socky.send("update_list_of_running_experiments(#{experiment.id})", :channels => "experiment_state_changed")

      render :inline => experiment_id.to_s
    end
  end

  # if there is a running DF experiment it returns an archive with repository
  # which contains all the necessary configuration files
  def get_repository
    send_file(File.join(Rails.public_path, "repository.tar.gz"), :type => "application/x-gzip")
  end

  # getting parameters of an experiment instance to compute in format "<instance_id>#<log_file_path>"
  def next_configuration
    begin
      experiment = Experiment.find_in_db(params[:experiment_id])
      raise "Experiment is not running any more" if not experiment.is_running

      instance_to_send = experiment.get_next_instance

      if instance_to_send
        log_file_path = make_instance_log_file(instance_to_send)
        instance_to_send.put_in_cache

        experiment.progress_bar_update(instance_to_send.id.to_i, "sent")

        render :inline => "#{instance_to_send.id}##{log_file_path}#" +
            "#{experiment.time_constraint_in_sec}##{experiment.time_constraint_in_iter}"
      else
        render :inline => "All sent"
      end

    rescue Exception => e
      logger.debug("Error1 --- " + e.to_s)
      render :inline => "None"
    end
  end

  # modern version of the next_configuration method; returns a json document with all necessary information to start a simulation
  def next_simulation
    simulation_doc = {}

    begin
      experiment = Experiment.find_in_db(params[:experiment_id])
      raise "Experiment is not running any more" if not experiment.is_running

      simulation_to_send = experiment.get_next_instance

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

  # getting actual XML document of a concrete instance
  def configuration
    begin
      instance = ExperimentInstance.cache_get(params[:experiment_id], params[:instance_id])

      simulation_scenario = DataFarmingScenario.new(nil)
      simulation_scenario.load_tamplate_from_cache(params[:experiment_id])
      simulation_xml = simulation_scenario.prepare_xml_for_simulation(instance.arguments.split(","), instance.values.split(","))

      render :inline => simulation_xml
    rescue Exception => e
      Rails.logger.error("Error2 - #{e}")
      render :inline => "NOT OK", :status => 404
    end
  end

  #change configuration state to 'done' and write results to a shared file
  def set_configuration_done
    begin
      experiment = Experiment.find(params[:experiment_id].to_i)
      instance = ExperimentInstance.cache_get(params[:experiment_id], params[:instance_id])

      if instance.nil? or instance.is_done
        logger.debug("Experiment Instance #{params[:instance_id]} of experiment #{params[:experiment_id]} is already done or is nil? #{instance.nil?}")
      else
        instance.is_done = true
        instance.to_sent = false
        instance.result = params[:instance_result].split(",").map { |result|
          split_result = result.split("=")
          split_result[1] = format("%.4f", split_result[1].to_f)
          split_result.join("=")
        }.join(",")
        instance.done_at = Time.now
        instance.save
        instance.remove_from_cache

        experiment.progress_bar_update(params[:instance_id].to_i, "done")
      end

      render :inline => "OK"

    rescue Exception => e
      logger.error("Error3 --- #{e}")
      render :inline => "NOT OK", :status => 404
    end
  end

  def update_state
    @experiment = Experiment.find_by_id(params[:experiment_id])
    @all = ExperimentInstance.count_all(params[:experiment_id])
    @done, @sent = ExperimentInstance.get_statistics(params[:experiment_id])

    respond_to do |format|
      format.js {
        render :inline => "if($('#pb_busy:visible').length == 0) {
            $('#monitoring_section').html('<%= escape_javascript(render :partial => 'monitoring_section') %>');
          }"
      }
    end
  end

  def experiment_stats
    experiment = Experiment.find(params[:id])

    stats = if experiment
        generated, instances_done, instances_sent = experiment.get_statistics
        if generated > experiment.experiment_size
          experiment.experiment_size = generated
          experiment.save_and_cache
        end

        #Rails.logger.debug("Progress Bar: #{experiment.experiment_progress_bar.progress_bar_color.join(",")}")
        
        partial_stats = {
          "all" => experiment.experiment_size, "sent" => instances_sent, "done_num" => instances_done,
          "done_percentage" => "'%.2f'" % ((instances_done.to_f / experiment.experiment_size) * 100),
          "generated" => [generated, experiment.experiment_size].min, 
          "progress_bar" => "[#{experiment.experiment_progress_bar.progress_bar_color.join(",")}]"
        }
        
        if instances_done > 0 and (instances_done % 3 == 0 or instances_done == experiment.experiment_size)
          ei_perform_time_avg = ExperimentInstance.get_avg_execution_time_of_ei(experiment.id)
          ei_perform_time_avg_m = (ei_perform_time_avg / 60.to_f).floor
          ei_perform_time_avg_s = (ei_perform_time_avg - ei_perform_time_avg_m*60).to_i
          
          ei_perform_time_avg = ""
          ei_perform_time_avg += "#{ei_perform_time_avg_m} minutes"  if ei_perform_time_avg_m > 0
          ei_perform_time_avg += " and " if (ei_perform_time_avg_m > 0) and (ei_perform_time_avg_s > 0)
          ei_perform_time_avg +=  "#{ei_perform_time_avg_s} seconds" if ei_perform_time_avg_s > 0
          
          # ei_perform_time_avg = "%.2f" % ei_perform_time_avg
          partial_stats["avg_simulation_time"] = ei_perform_time_avg
        
          predicted_finish_time = (Time.now - experiment.created_at).to_f / 3600
          predicted_finish_time /= (instances_done.to_f / experiment.experiment_size)
          predicted_finish_time_h = predicted_finish_time.floor
          predicted_finish_time_m = ((predicted_finish_time.to_f - predicted_finish_time_h.to_f)*60).to_i
          
          predicted_finish_time = ""
          predicted_finish_time += "#{predicted_finish_time_h} hours"  if predicted_finish_time_h > 0
          predicted_finish_time += " and " if (predicted_finish_time_h > 0) and (predicted_finish_time_m > 0)
          predicted_finish_time +=  "#{predicted_finish_time_m} minutes" if predicted_finish_time_m > 0
    
          partial_stats["predicted_finish_time"] = predicted_finish_time
        end

        partial_stats
      else
        {
            "all" => 0, "sent" => 0, "done_num" => 0, "done_percentage" => "'0.00'", "generated" => 0, "progress_bar" => "[]"
        }
      end

    respond_to do |format|
      format.json { render :json => stats }
    end
  end

  def experiment_moes
    experiment = Experiment.find(params[:id])
    moes_info = {}  
    
    moes = experiment.moe_names
    moes = moes.nil? ? ["No MoEs found", "nil"] : moes.map{|x| [ParameterForm.moe_label(x), x]}
    
    
    done_instance = ExperimentInstance.get_first_done(experiment.id)
    moes_and_params = if done_instance.nil?
        ["No input parameters found", "nil"]
      else
        moes + [["-----------", "nil"]] + 
        done_instance.arguments.split(",").map{|x| [ParameterForm.parameter_label_with_agent_id(x), x]}
      end
    
    moes_info[:moes] = moes.map{|label, id| "<option value='#{id}'>#{label}</option>"}.join()
    moes_info[:moes_and_params] = moes_and_params.map{|label, id| "<option value='#{id}'>#{label}</option>"}.join()
    
    # logger.debug moes_info.to_s
    
    respond_to do |format|
      format.json{ render :json => moes_info }
    end  
  end
  
  def update_list_of_running_experiments
    @running_experiments = Experiment.running_experiments

    respond_to do |format|
      format.js {
        render :inline => "window.location.reload()"
        #render :inline => "$('#list_of_running_experiments').html('#{}" +
        #    escape_javascript(render :partial => 'running_experiments') + ");"
      }
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
      experiment = Experiment.find_by_id(params[:experiment_id])

      file_path = File.join(Rails.public_path, "data", "configurations.txt")
      File.open(file_path, "w") do |file|
        experiment.experiment_instances.each do |instance|
          # logger.info(instance.values)
          file.puts instance.values
        end
      end
      send_file(file_path, :type => "text/plain")
    rescue
      render :inline => "No experiment with the given id", :status => 404
    end
  end

  def add_chart
    @chart_data = get_chart_data(params[:experiment_id], params[:argument_name], params[:moe_name])

    respond_to do |format|
      format.js
    end
  end

  def update_chart_data
    @chart_data = get_chart_data(params[:experiment_id], params[:argument_name], params[:moe_name])

    respond_to do |format|
      format.js {
        render :inline => "chart_tab[#{params[:chart_id]}].series[0].setData([#{@chart_data}]);"
      }
    end
  end

  def add_regression_tree_chart
    create_regression_tree_chart

    respond_to do |format|
      format.js
    end
  end

  def update_regression_tree
    create_regression_tree_chart

    respond_to do |format|
      format.js
    end
  end

  def add_basic_statistics_chart
    get_basic_statistics_about_moe

    respond_to do |format|
      format.js
    end
  end

  def update_basic_statistics_chart
    @chart_id = params[:chart_id]
      get_basic_statistics_about_moe

    respond_to do |format|
      format.js
    end
  end

  def add_bivariate_analysis_chart
    prepare_bivariate_chart_data

    respond_to do |format|
      format.js
    end
  end

  def refresh_bivariate_analysis_chart
    prepare_bivariate_chart_data
    @chart_id = params[:chart_id].split("_").last

    @chart_data = ""
    @chart_values.each do |x_value, y_values|
      y_values.each do |y_value|
        @chart_data += "[ #{x_value}, #{y_value} ],"
      end
    end

    respond_to do |format|
      format.js
    end
  end

  def get_parameter_values
    @experiment = Experiment.find(params[:experiment_id])

    @param_r_id = params[:param_name]
    @parameter_uid, @parametrization_type = @experiment.parametrization_of(@param_r_id)

    @param_type = {}
    @param_type['type'] = @parametrization_type
    @param_values = @experiment.generated_parameter_values_for(@param_r_id)
  end

  #TODO FIXME refactor to be one screen height
  def extend_input_values
    @experiment = Experiment.find(params[:experiment_id])
    @param_name = params[:param_name]
    @range_min = params[:range_min].to_f
    @range_max = params[:range_max].to_f
    @range_step = params[:range_step].to_f
    @priority = params[:priority].to_i
    
    @new_instance_counter, offset = 0, @experiment.experiment_size + 1

    sample_instance = ExperimentInstance.find_by_id(@experiment.id, 1)
    param_index = sample_instance.arguments.split(",").map{|x| ParameterForm.parameter_uid_for_r(x)}.index(@param_name)
    sample_value = sample_instance.values.split(",")[param_index]
    # Getting combinations of other parameters
    # values,arguments
    instances_to_reproduce = ExperimentInstance.raw_find_by_query(@experiment.id, {}, {:fields => ["values","arguments"]}).select{ |instance|
      instance["values"].split(",")[param_index] == sample_value
    }
    instances_to_reproduce_count = instances_to_reproduce.size*@experiment.run_counter*@range_min.step(@range_max, @range_step).to_a.size

    # create additional partitions
    instance_dbs = ExperimentInstanceDb.all
    raise "No ExperimentInstanceDb defined, hence could not create experiment partitions." if instance_dbs.empty?

    partitions = @experiment.instances_partitioning(instances_to_reproduce_count, instance_dbs.size, @experiment.experiment_size)
    0.upto(partitions.size - 1) do |index|
      partition_hash = partitions[index]
      Rails.logger.debug("Index: #{index} - #{partition_hash}")

      partition = ExperimentPartition.create(:experiment_id => @experiment.id,
        :experiment_instance_db_id => instance_dbs[partition_hash[:db_index]].id,
        :start_id => partition_hash[:start_id],
        :end_id => partition_hash[:end_id])

      partition.create_table if index < instance_dbs.size
    end

    logger.debug "Number of instances to reproduce #{instances_to_reproduce_count}"
    @experiment.experiment_size += instances_to_reproduce_count
    @experiment.save_and_cache
    
    columns = ["id", "experiment_id", "is_done", "to_sent", "run_index", "random_value", "priority", "arguments", "values"]
    combinations = []
    
    instances_to_reproduce.each do |instance|
      new_values = instance["values"].split(",")
      
      @range_min.step(@range_max, @range_step).each do |value|
        new_values[param_index] = value
        
        1.upto(@experiment.run_counter).each do |counter|
          values = [offset + @new_instance_counter, @experiment.id, false, true, counter, rand(), @priority, instance["arguments"], new_values.join(",")]
          combinations << values
          
          @new_instance_counter += 1
          
          if combinations.size >= 1000
            begin
              ExperimentInstance.bulk_insert(@experiment.id, combinations, columns)
            rescue Exception => e
              Rails.logger.debug("Exception occured while inserting instances: #{e}")
              return
            end
            combinations = []
          end
        end
        
      end
    end
    
    # insert the last set of combinations
    logger.debug("Insert last instances: #{@experiment.id} --- #{combinations.size}")
    begin
      ExperimentInstance.bulk_insert(@experiment.id, combinations, columns)
    rescue Exception => e
      Rails.logger.debug("Exception occured while inserting instances: #{e}")
      return
    end

    spawn(:method => :thread) do
      @experiment.experiment_progress_bar.update_all_bars
    end

    @experiment.save_and_cache

    respond_to do |format|
      format.js{ render :inline => "$('#dialog').parent().hide(); $('#expand_dialog_busy').hide(); alert('#{@new_instance_counter} instances created');" }  
    end
  end

  def check_experiment_size
    experiment = Experiment.find(params[:experiment_id])

    if experiment then
      parameters, doe_groups = experiment.create_parameters_and_doe_groups(select_params_for_parameters_and_doe_groups)
      Rails.logger.debug("After parameters and doe groups creation")
      exp_size = (compute_experiment_size(parameters, doe_groups) * experiment.run_counter).to_s.with_delimeters
      Rails.logger.debug("After completing exp_size calculation")

      render :inline => "$('#experiment_size_dialog').dialog('open');
                         $('#experiment_size_num').html('#{exp_size}')"
    else
      render :inline => "alert('Experiment is not available anymore.')"
    end
  end

  def change_scheduling_policy
    experiment = Experiment.find_by_id(params[:experiment_id])
    new_scheduling_policy = params[:scheduling_policy]

    experiment.scheduling_policy = new_scheduling_policy
    if experiment.save_and_cache then
      msg = "The scheduling policy of the experiment has been changed."
    else
      msg = "The scheduling policy of the experiment could not have been changed due to internal server issues."
    end

    respond_to do |format|
      format.js {
        render :inline => "$('#general_purpose_dialog').html('#{msg}');" +
            "$('#general_purpose_dialog').dialog('open');" +
            "$('#loading-img').hide();" +
            "$('#policy_name').html('#{new_scheduling_policy}');"
      }
    end
  end

  def latest_running_experiment
    experiment = get_latest_running_experiment

    if experiment
      redirect_to :action => "monitor", :experiment_id => experiment.id
    else
      redirect_to :action => "index"
    end
  end

  def completed_simulations_count
    experiment = Experiment.find(params[:id])

    simulation_counter = if experiment
                experiment.completed_simulations_count_for(params[:secs].to_i)
              else
                0
              end

    respond_to do |format|
      format.json { render :json => { "count" => simulation_counter } }
    end
  end

  def code_base
    experiment_id = params['id'].to_i
    simulation = DataFarmingExperiment.find_by_experiment_id(experiment_id).simulation
    code_base_dir = Dir.mktmpdir('code_base')

    file_list = %w(input_writer executor output_reader)
    file_list.each do |filename|
      IO.write("#{code_base_dir}/#{filename}", simulation.send(filename).code)
    end
    IO.binwrite("#{code_base_dir}/simulation_binaries.zip", simulation.simulation_binaries)
    file_list << 'simulation_binaries.zip'

    zipfile_name = File.join('/tmp', "experiment_#{experiment_id}_code_base.zip")

    File.delete(zipfile_name) if File.exist?(zipfile_name)

    Zip::ZipFile.open(zipfile_name, Zip::ZipFile::CREATE) do |zipfile|
      file_list.each do |filename|
        zipfile.add(filename, File.join(code_base_dir, filename))
      end
    end

    FileUtils.rm_rf(code_base_dir)

    send_file zipfile_name, :type => 'application/zip'
  end

  private

  def get_latest_running_experiment
    user = User.find_by_id(session[:user])
    user.experiments.where(:is_running => true).order("id").first
  end
  
  def select_params_for_parameters_and_doe_groups
    params_to_override = params.select { |key, value| key.starts_with? "Agent" } 
    params_groups_for_doe = params.select { |key, value| key.starts_with?("doe_") and key.ends_with?("_params") }
    
    return params_to_override, params_groups_for_doe
  end

  def compute_experiment_size(parameters, doe_groups)
    exp_size = parameters.reduce(1) { |acc, param_node| acc *= param_node.values.size }
    doe_groups.reduce(exp_size) { |acc, group|
      acc *= group[1].size(File.join(Rails.root, "lib", "designs.R"))
    }
  end

  def set_monitoring_view_params(experiment_id)
    experiment = Experiment.find_by_id(experiment_id)

    @all = ExperimentInstance.count_with_query(experiment_id)
    @done, @sent = ExperimentInstance.get_statistics(experiment_id)
    @parts_per_slot, @number_of_bars = experiment.experiment_progress_bar.basic_progress_bar_info
    Rails.logger.debug("EXP id: #{experiment_id} --- Generated: #{@all} --- Done: #{@done}\
    --- Sent: #{@sent} --- Parts: #{@parts_per_slot} --- Bars: #{@number_of_bars}")

    @bar_colors = experiment.experiment_progress_bar.progress_bar_color

    if @done > 0 then
      @ei_perform_time_avg = ExperimentInstance.get_avg_execution_time_of_ei(experiment_id)
      @ei_perform_time_avg = "%.2f" % @ei_perform_time_avg
    else
      @ei_perform_time_avg = "Not available yet"
    end

    if @done < 20 then
      @predicted_finish_time = "Not available yet"
    else
      @predicted_finish_time = (Time.now - experiment.created_at).to_f / 3600
      @predicted_finish_time /= (@done.to_f / experiment.experiment_size)

      @predicted_finish_time = "%.2f" % @predicted_finish_time
    end
  end

  def make_instance_log_file(instance)
    instance_folder_name = instance.id.to_s
     # if instance.run_index > 1 then
                             # (instance_id - instance.run_index + 1).id.to_s
                           # else
                             # instance.id.to_s
                           # end

    instance_dir = File.join(Experiment.find(instance.experiment_id).data_folder_path, instance_folder_name)
    # TODO temp removal
    #begin
    #  if not File.exists?(instance_dir) then
    #    Dir::mkdir(instance_dir)
    #  end
    #rescue Exception => e
    #  logger.debug("ERROR: make_instance_log_file - #{e}")
    #end

    # unnecessery -> everything is in a database
    #File.open(File.join(instance_dir, "configuration.txt"), "w") do |file|
    #  values = instance.values.split(",")
    #  instance.arguments.split(",").each_with_index do |arg, index|
    #    file.puts "#{arg} = #{values[index]}"
    #  end
    #end

    File.join(instance_dir, "run#{instance.run_index}.log")
  end

  def get_agents_elements(simulation_scenario_name)
    scenario_file = File.join(Rails.configuration.scenarios_path, simulation_scenario_name)
    results = ScenarioFileParser.parse_scenario_file(scenario_file)

    return results
  end

  def get_chart_data(experiment_id, argument, moe)
    chart_data = ""
    instances = ExperimentInstance.find_by_query(experiment_id, {:is_done => true})
    instances.each do |instance|
      argument_index = instance.arguments.split(',').find_index(argument)
      moe_text = instance.result.split(',').find { |item| item.start_with?(moe + "=") }
      chart_data += "[#{instance.values.split(',')[argument_index]}, #{moe_text.split("=")[1]}],"
    end

    chart_data[0..-2]
  end

  def parse_regression_tree_data(tree_data)
    nodes = {}
    starting_lines = []
    tree_data.each_with_index do |line, index|
      starting_lines << index if line.start_with?("Node number")
    end

    starting_lines.each_with_index do |s_index, index|
      node_data = if index < starting_lines.size - 1 then
                    tree_data[s_index..(starting_lines[index+1] - 1)]
                  else
                    tree_data[s_index..-1]
                  end
      node_id, node_map = parse_regression_tree_node(node_data)
      nodes[node_id] = node_map
    end

    nodes
  end

  def parse_regression_tree_node(node_data)
    node_map = {}

    first_line = node_data.first
    colon_ind = first_line.index(":")
    id = first_line["Node number ".size...colon_ind].to_i
    node_map["id"] = id
    node_map["n"] = first_line[(colon_ind+2)..(first_line.index("observation")-2)].to_i

    second_line = node_data[1]
    second_line = second_line.split(",")[0]
    mean = second_line.split("=")[1].to_f
    node_map["mean"] = mean

    # check for children
    if node_data.size > 3 then
      sons_line = node_data[2]
      left_son = sons_line[(sons_line.index("=")+1)...sons_line.index("(")].to_i
      node_map["left"] = left_son

      right_son = sons_line[(sons_line.rindex("=")+1)...sons_line.rindex("(")].to_i
      node_map["right"] = right_son


      question_line = node_data[4]
      question = question_line.split("to the")[0].split(" ")
      node_map["param_id"] = question.first
      node_map["param_label"] = ParameterForm.parameter_label_from(question.first)
      question[0] = ParameterForm.parameter_label_from(question.first)
      question = question.join(" ")

      node_map["question"] = question
    end

    return id, node_map
  end

  def create_regression_tree_chart
    @experiment = Experiment.find(params[:experiment_id])
    @moe_name = params[:moe_name]
    result_file = @experiment.create_result_file_for(@moe_name)

    arguments = @experiment.range_arguments.join("+")

    rinruby = Rails.configuration.eusas_rinruby
    
    rinruby.eval("
      library(rpart)
      experiment_data <- read.csv('#{result_file}')
      fit <- rpart(#{@moe_name}~#{arguments},method='anova',data=experiment_data)
      fit_to_string <- capture.output(summary(fit))
    ")

    @tree_nodes = nil
    begin
      @tree_nodes = parse_regression_tree_data(rinruby.fit_to_string)
    rescue Exception => e
      logger.debug(e.inspect)
      logger.debug(e.backtrace)
      logger.info("Could not create regression tree chart for #{@moe_name}. Probably too few simulations were performed.")
    end
  end

  def prepare_bivariate_chart_data
    @experiment = Experiment.find(params[:experiment_id])
    @x_axis, @y_axis = ParameterForm.parameter_uid_for_r(params[:x_axis]), ParameterForm.parameter_uid_for_r(params[:y_axis])
    result_file = @experiment.create_result_file_for_scatter_plot(@x_axis, @y_axis)
    @chart_values = Hash.new

    column_x_idx, column_y_idx = -1, -1
    CSV.foreach(result_file) do |row|
      if column_x_idx < 0 then
        column_x_idx = row.index(@x_axis)
        column_y_idx = row.index(@y_axis)
      else
        if @chart_values.has_key? row[column_x_idx]
          @chart_values[row[column_x_idx]] << row[column_y_idx]
        else
          @chart_values[row[column_x_idx]] = [row[column_y_idx]]
        end
      end
    end
    
  end

  def get_basic_statistics_about_moe
    @experiment = Experiment.find(params[:experiment_id])
    result_file = @experiment.create_result_file_for(params[:moe_name])
    @moe_name = params[:moe_name]
    @resolution = params[:resolution].to_i

    rinruby = Rails.configuration.eusas_rinruby    
    rinruby.eval("
      experiment_data <- read.csv(\"#{result_file}\")
      ex_min <- min(experiment_data$#{@moe_name})
      ex_max <- max(experiment_data$#{@moe_name})
      ex_sd <- sd(experiment_data$#{@moe_name})
      ex_mean <- mean(experiment_data$#{@moe_name})
    ")
    @ex_min = format("%.2f", rinruby.ex_min)
    @ex_max = format("%.2f", rinruby.ex_max)
    @ex_sd = format("%.2f", rinruby.ex_sd)
    @ex_mean = format("%.2f", rinruby.ex_mean)

    get_moe_value_map(result_file, @moe_name, @ex_min.to_f, @ex_max.to_f, @resolution)
  end

  def get_moe_value_map(result_file, column_name, min_value, max_value, slices_num=10)
    column_index = -1
    slice_width = [(max_value - min_value) / slices_num, 1].max

    if max_value == min_value
      slice_width = [max_value, 1].max
      slices_num = 1
    end

    @bucket_names = Array.new(slices_num) { |ind|
      if ind == slices_num - 1
        "[#{'%.1f'%(min_value + slice_width*ind)}-#{'%.1f'%(min_value + slice_width*(ind+1))}]"
      else
        "[#{'%.1f'%(min_value + slice_width*ind)}-#{'%.1f'%(min_value + slice_width*(ind+1))})"
      end
    }
    @buckets = Array.new(slices_num) { 0 }

    CSV.foreach(result_file) do |row|
      if column_index < 0 then
        column_index = row.index(column_name)
      else
        @buckets[[((row[column_index].to_f-min_value) / slice_width).floor, @buckets.size-1].min] += 1
      end
    end
    
  end

  def update_monitoring_view(experiment)
    spawn do
      instances_done, instances_sent = ExperimentInstance.get_statistics(experiment.id)
      statistics = [instances_sent, instances_done, experiment.experiment_size,
                    "'%.2f'" % ((instances_done.to_f / experiment.experiment_size) * 100)]
      logger.debug("Statistics: #{statistics}")

      if instances_done > 0 and (instances_done % 10 == 0 or instances_done == experiment.experiment_size)
        ei_perform_time_avg = ExperimentInstance.get_avg_execution_time_of_ei(experiment.id)
        ei_perform_time_avg = "%.2f" % ei_perform_time_avg
        statistics << ei_perform_time_avg

        predicted_finish_time = (Time.now - experiment.created_at).to_f / 3600
        predicted_finish_time /= (instances_done.to_f / experiment.experiment_size)
        predicted_finish_time = "%.2f" % predicted_finish_time

        statistics << predicted_finish_time
      end

      bar_colors = experiment.experiment_progress_bar.progress_bar_color
      # Socky.send("update_monitoring_section([#{bar_colors.join(',')}], [#{statistics.join(",")}])",
                 # :channels => "experiment_monitoring_#{experiment.id}")
    end
  end

  def prepare_agent_elements
    @agent_elements = get_agents_elements(params[:scenario_id])
    @agents_hierarchy, @agent_in_hierarchy_ids = DataFarmingScenario.new(params[:scenario_id]).agents_layout(@agent_elements)
  end

  def update_moe_list_if_first(instance)
    spawn do
      instances_done = ExperimentInstance.count_with_query(instance.experiment.id, {"is_done" => true})
      if instances_done == 1 then
        options = instance.result.split(',').map { |item| item.split("=")[0] }
        options_txt = options.reduce("") { |acc, t| acc += "<option value='#{t}'>#{t}</option>" }
        # Socky.send("$(\"[name='moe_name']\").each(function(ind,obj) { $(obj).html(\"#{options_txt}\") })",
                   # :channels => "experiment_monitoring_#{instance.experiment_id}")
      end

      # Socky.send("update_list_of_running_experiments(#{instance.experiment_id})", :channels => "experiment_state_changed")
    end
  end

end
