require 'zip'
require 'infrastructure_facades/infrastructure_facade'
require 'csv'
require 'json'
require 'erb'

class ExperimentsController < ApplicationController
  include SSHAccessedInfrastructure

  before_filter :load_experiment, except: [:index, :share, :new, :random_experiment]
  before_filter :load_simulation, only: [ :create, :new, :calculate_experiment_size,
                                          :start_custom_points_experiment, :start_supervised_experiment]

  def index
    load_simulations_and_experiments_for_current_user

    respond_to do |format|
      format.html
      format.json { render json: {
          status: 'ok',
          running: @running_experiments.collect { |e| e.id.to_s },
          completed: @completed_experiments.collect {|e| e.id.to_s},
          historical: @historical_experiments.collect { |e| e.id.to_s }
      }}
    end
  end

  ##
  # Sets instance variables:
  # - @running_experiments
  # - @historical_experiments
  # - @completed_experiments
  # - @simulations
  # Containing models for current user
  def load_simulations_and_experiments_for_current_user
    @non_historical_experiments = load_non_historical_experiments
    @running_experiments = load_running_experiments
    @completed_experiments = load_completed_experiments
    @historical_experiments = load_historical_experiments
    @simulations = load_simulations
  end

  def load_non_historical_experiments
    (current_user.get_running_experiments.sort do |e1, e2|
      e2.start_at <=> e1.start_at
    end).map do |e|
      transform_experiment e
    end
  end

  def load_running_experiments
    @non_historical_experiments ||= load_non_historical_experiments

    @non_historical_experiments.select {|e| not e.completed?} # running and completed
  end

  def load_historical_experiments
    current_user.get_historical_experiments.sort { |e1, e2| e2.end_at <=> e1.end_at }
  end

  def load_completed_experiments
    @non_historical_experiments ||= load_non_historical_experiments

    @non_historical_experiments.select {|e| e.completed?} # running and not completed
  end

  def load_simulations
    current_user.get_simulation_scenarios
  end

  def show
    information_service = InformationService.instance
    @public_storage_manager_url = information_service.sample_public_url 'storage_managers'
    @public_chart_service_url = information_service.sample_public_url 'chart_services'

    @storage_manager_url = (Rails.application.secrets[:storage_manager_url] or @public_storage_manager_url)

    begin
      start_update_bars_thread if Time.now - @experiment.start_at > 30
    rescue Exception => e
      flash[:error] = t('experiments.not_found', { id: @experiment.id, user: current_user.login })
      respond_to do |format|
        format.html { redirect_to action: :index }
        format.json { render json: {status: 'error', message: "experiment with id #{id.to_s} not found"} }
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: {status: 'ok', data: @experiment.to_h } }
    end
  end

  def start_update_bars_thread
    Thread.start do
      Rails.logger.debug("Updating all progress bars --- #{Time.now - @experiment.start_at}")
      @experiment.update_all_bars
    end
  end

  def running_experiments
    @running_experiments = current_user.get_running_experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }
    @running_experiments.map! {|e| transform_experiment e}
    @running_experiments.select! {|e| not e.completed?} # running and not completed

    render partial: 'running_experiments', locals: { show_close_button: true }
  end

  def completed_experiments
    @completed_experiments = current_user.get_running_experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }
    @completed_experiments.map! {|e| transform_experiment e}
    @completed_experiments.select! {|e| e.completed?} # running and completed

    render partial: 'completed_experiments', locals: { show_close_button: true }
  end

  def historical_experiments
    @historical_experiments = current_user.get_historical_experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }

    render partial: 'historical_experiments', locals: { show_close_button: true }
  end

  def get_booster_dialog
    render inline: render_to_string(partial: 'booster_dialog')
  end

  # stops the currently running DF experiment (if any)
  def stop
    raise SecurityError.new(t('experiments.stop.failure')) unless current_user_owns_experiment?

    @experiment.stop!

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.json { render json: { status: 'ok' } }
    end
  end

  def current_user_owns_experiment?
    @experiment.user_id == current_user.id
  end

=begin
  @apiDefine ConfigurationsParams

  @apiParam {Number=0,1} with_index=0 "1" to add simulation index column to result CSV
  @apiParam {Number=0,1} with_params=0 "1" to add params columns to result CSV
  @apiParam {Number=0,1} with_moes=1 "1" to add moes columns to result CSV
=end

=begin
  @api {get} /experiments/:id/file_with_configurations Get CSV file with simulation runs results
  @apiName GetFileWithConfigurations
  @apiGroup Experiments

  @apiUse ConfigurationsParams
=end
  def file_with_configurations
    send_data(_configurations_csv,
              type: 'text/plain', filename: "configurations_#{@experiment.id}.txt")
  end

=begin
  @api {get} /experiments/:id/configurations Get CSV text with simulation runs results
  @apiName GetConfigurations
  @apiGroup Experiments

  @apiUse ConfigurationsParams
=end
  def configurations
    respond_to do |format|
      format.html { render text: _configurations_csv.gsub("\n", '<br/>') }
      format.json { render json: {status: 'ok', data: _configurations_csv} }
    end
  end

  # NOT a controller method, only helper
  def _configurations_csv
    validate(
        with_index: [:optional, :security_default],
        with_params: [:optional, :security_default],
        with_moes: [:optional, :security_default]
    )

    w_index = (params.include?(:with_index) ? (params[:with_index] == '1') : false)
    w_params = (params.include?(:with_params) ? (params[:with_params] == '1') : true)
    w_moes = (params.include?(:with_moes) ? (params[:with_moes] == '1') : true)

    @experiment.create_result_csv(w_index, w_params, w_moes)
  end

  def create_experiment
    #validate_params(:json, :doe) # TODO :experiment_input :parameters_constraints,

    begin
      parse = lambda do |id, parse_method|
        if params[id].blank?
          params.delete id
        else
          params[id] = parse_method.call(params[id])
        end
      end

      parse.call :replication_level, lambda {|x| x.to_i}
      parse.call :execution_time_constraint, lambda {|x| x.to_i * 60}
      parse.call :parameters_constraints, lambda {|x| Utils.parse_json_if_string(x)}

      parsed_params = params.permit(:replication_level, :time_constraint_in_sec, :scheduling_policy, :experiment_name,
                                   :experiment_description, :parameter_constraints)
      experiment = ExperimentFactory.create_experiment(current_user.id, @simulation, parsed_params)

      if request.fullpath.include?("start_import_based_experiment")
        input_space_imported_specification(experiment)
      else
        input_space_manual_specification(experiment)
      end

      unless flash[:error]
        experiment.labels = experiment.parameters.flatten.join(',')
        experiment.save
        experiment.experiment_id = experiment.id
        begin
          experiment.experiment_size(true)
        rescue Exception => e
          Rails.logger.warn("An exception occured: #{e.message}\n#{e.backtrace.join("\n")}")
          flash[:error] = t(e.message, default: e.message)
          experiment.size = 0
        end

        if experiment.size == 0
          flash[:error] = t('experiments.errors.zero_size') if flash[:error].blank?
          experiment.destroy
        else
          experiment.save
          # create progress bar
          experiment.insert_initial_bar
          experiment.simulation_runs.create_table
        end
      end

      unless flash[:error].blank?
        respond_to do |format|
          format.html { redirect_to experiments_path }
          format.json { render json: {status: 'error', message: flash[:error]} }
        end
      else
        respond_to do |format|
          format.html { redirect_to experiment_path(experiment.id) }
          format.json { render json: {status: 'ok', experiment_id: experiment.id.to_s} }
        end
      end
    rescue Exception => e
      Rails.logger.error "Exception in ExperimentsController create: #{e.to_s}\n#{e.backtrace.join("\n")}"
      flash[:error] = e.to_s

      respond_to do |format|
        format.html { redirect_to experiments_path }
        format.json { render json: {status: 'error', message: flash[:error]} }
      end
    end
  end

  # POST params:
  # - simulation_id
  # TODO: other experiment parameters
  # TODO: handle errors
  def create_custom_points_experiment
    validate(
        simulation_id: :security_default
    )

    experiment = ExperimentFactory.create_custom_points_experiment(current_user.id, @simulation)
    experiment.save

    render json: {status: 'ok', experiment_id: experiment.id.to_s}
  end

=begin
  @api {post} /experiments/ Create SupervisedExperiment
  @apiName start_supervised_experiment
  @apiGroup Experiments
  @apiDescription This action allows user to start new supervised experiment with given parameters.
  Action supports two possible result formats:
  * .json - json with info about performed action
  * .html - redirection to experiment view page

  @apiParam {String} type experiment type. must be 'supervised'
  @apiParam {String} simulation_id  ID of simulation used to perform experiment
  @apiParam {String} [supervisor_script_id] ID of supervisor script used to manage experiment, without this
                      param supervisor script will not be started
  @apiParam {json} [supervisor_script_params] Parameters passed to supervisor script, mandatory when
                      supervisor_script_id is present

  @apiParamExample Params-Example
    type: 'supervised'
    simulation_id: '551fca1f2ab4f259fc000002'
    supervisor_script_id: 'simulated annealing'
    supervisor_script_params:
      {
        "maxiter": 2,
        "dwell": 1,
        "schedule": "boltzmann"
      }

  @apiSuccess {Object} info json object with information about performed action
  @apiSuccess {String} info.status status of performed action, on success always 'ok'
  @apiSuccess {String} info.experiment_id id of created experiment
  @apiSuccess {Number} [info.pid] pid of supervisor script managing experiment, only when
                      supervisor_script_id param is present

  @apiSuccessExample {json} Success-Response
    {
      'status': 'ok'
      'experiment_id': '551fc1932ab4f259fc000001'
      'pid': 1234
    }

  @apiError {Object} info json object with information about performed action
  @apiError {String} info.status status of performed action, on failure always 'error'
  @apiError {String} info.reason reason of failure to start experiment

  @apiErrorExample {json} Failure-Response
    {
      'status': 'error'
      'reason': 'Unable to connect with Experiment Supervisor'
    }
=end

  def parse_json_if_string2(value)
    value.kind_of?(String) and JSON.parse(value) or value
  end

  def create_supervised_experiment
    validate(
        simulation_id: :security_default,
        supervisor_script_id: [:optional, :security_default]
        #supervisor_script_params: [:optional, :json_or_hash]
    )
    # TODO: other experiment parameters
    # TODO: handle errors

    parse = lambda do |id, parse_method|
      if params[id].blank?
        params.delete id
      else
        params[id] = parse_method.call(params[id])
      end
    end

    parse.call :replication_level, lambda {|x| x.to_i}
    parse.call :execution_time_constraint, lambda {|x| x.to_i * 60}

    parsed_params = params.permit(:replication_level, :time_constraint_in_sec, :scheduling_policy, :experiment_name,
                                  :experiment_description)
    experiment = ExperimentFactory.create_supervised_experiment(current_user.id, @simulation, parsed_params)

    experiment.save
    response = {'status' => 'ok'}



    supervisor_script_params_tmp = (params[:supervisor_script_params] == '' ? {} : params[:supervisor_script_params])

    if params.has_key?(:supervisor_script_id)
      response = experiment.start_supervisor_script(params[:simulation_id],
                                                    params[:supervisor_script_id],
                                                    Utils::parse_json_if_string(supervisor_script_params_tmp),
                                                    current_user
      )
      Rails.logger.debug("Start supervisor script request to supervisor, response: #{response}")
    end

    response.merge!({experiment_id: experiment.id.to_s}) if response['status'] == 'ok'
    if response['status'] == 'error'
      experiment.destroy
      flash['error'] = "There has been an error while creating new supervised experiment: #{response['reason']}"
    else
      experiment.save
    end

    respond_to do |format|
      format.html { (response['status'] == 'ok') ? redirect_to(experiment_path(experiment.id)) : redirect_to(experiments_path) }
      format.json { render json: response }
    end
  end

  CONSTRUCTORS = {
      'experiment' => :create_experiment,
      'custom_points' => :create_custom_points_experiment,
      'supervised' => :create_supervised_experiment
  }

  def create
    validate(
        replication_level: [:optional, :security_default, :integer, :positive],
        execution_time_constraint: [:optional, :security_default, :integer, :positive],
        parameter_constraints: [:optional, :security_json],
        type: [:optional, :security_default]
    )
    type = params[:type] || 'experiment'
    raise ValidationError.new('type', type, 'Not a correct experiment type') unless CONSTRUCTORS.has_key? type
    send(CONSTRUCTORS[type])
  end

  def calculate_experiment_size
    #validate_params(:json, :parameters_constraints, :doe) # TODO :experiment_input
    validate(
        replication_level: [:security_default, :integer, :positive]
    )

    doe_info = params['doe'].blank? ? [] : Utils.parse_json_if_string(params['doe']).delete_if { |_, parameter_list| parameter_list.first.nil? }

    @experiment_input = Experiment.prepare_experiment_input(@simulation, Utils.parse_json_if_string(params['experiment_input']), doe_info)

    # TODO: use ExperimentsFactory
    # create the new type of experiment object
    experiment = Experiment.new({ simulation_id: @simulation.id,
                                  experiment_input: @experiment_input,
                                  name: @simulation.name,
                                  doe_info: doe_info
                                })
    experiment.replication_level = params[:replication_level].blank? ? 1 : params[:replication_level].to_i
    experiment.parameters_constraints = params[:parameters_constraints].blank? ? {} : Utils.parse_json_if_string(params[:parameters_constraints])

    message = nil
    begin
      experiment_size = experiment.experiment_size(true)
    rescue Exception => e
      experiment_size = 0; message = e.to_s
      Rails.logger.warn("An exception occured: #{message}")
    end

    render json: { experiment_size: experiment_size, error: message }
  end

  def calculate_imported_experiment_size
    validate(
        replication_level: [:optional, :security_default]
    )

    parameters_to_include = params.keys.select{ |parameter|
      parameter.start_with?('param_') and params[parameter] == '1'
    }.map{ |parameter| parameter.split('param_').last }

    if parameters_to_include.blank? or params[:file_content].blank?

      render json: { experiment_size: 0 }

    else
      importer = ExperimentCsvImporter.new(params[:file_content], parameters_to_include)
      replication_level = params['replication_level'].blank? ? 1 : params['replication_level'].to_i

      render json: { experiment_size: importer.parameter_values.size * replication_level }
    end
  end

  ### Progress monitoring API

  def completed_simulations_count
    simulation_counter = @experiment.simulation_runs.where(is_done: true, 
      done_at: { '$gte' => (Time.now - params[:secs].to_i) }).count

    render json: {count: simulation_counter}
  end

  def stats
    sims_generated, sims_sent, sims_done = @experiment.get_statistics

    if sims_generated > @experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations generated for experiment #{@experiment.inspect}")
      sims_generated = @experiment.experiment_size
    end

    if sims_done > @experiment.experiment_size
      Rails.logger.error("FATAL - too many simulations done and sent for experiment #{@experiment.inspect}")
      sims_done = @experiment.experiment_size
    end

    if sims_done + sims_sent > @experiment.experiment_size
      sims_sent = @experiment.experiment_size - sims_done
    end

    #if sims_generated > @experiment.experiment_size
    #  @experiment.experiment_size = sims_generated
    #  @experiment.save
    #end


    if @experiment.experiment_size!=0
      percentage = (sims_done.to_f / @experiment.experiment_size) * 100
    else
      percentage=0
    end
    stats = {
        all: @experiment.experiment_size, sent: sims_sent, done_num: sims_done,
        done_percentage: "'%.2f'" % (percentage),
        generated: [sims_generated, @experiment.experiment_size].min,
        progress_bar: "[#{@experiment.progress_bar_color.join(',')}]"
    }

    # TODO - mean execution time and predicted time to finish the experiment
    if sims_done > 0 and (rand() < (sims_done.to_f / @experiment.experiment_size) or sims_done == @experiment.experiment_size)
      execution_time = @experiment.simulation_runs.where({is_done: true}, fields: %w(sent_at done_at)).reduce(0) do |acc, simulation_run|
        if simulation_run.done_at and simulation_run.sent_at
          acc += simulation_run.done_at - simulation_run.sent_at
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
  ##
  # new function return array of json with paramaeter id label and type
  def moes_json
    result_set = @experiment.result_names
    result_set = if result_set.blank?
       [t('experiments.analysis.no_results')]
     else
       result_set.map{|x| [Experiment.output_parameter_label_for(x), x, "moes_parameter"]}
     end
    moes_and_params = get_moes_and_params(result_set)
    array = []
    moes_and_params.map do |label, id, type|
      parameter_infos= {:label => ERB::Util.h(label), :id => ERB::Util.h(id), :type => ERB::Util.h(type)}
      array.push(parameter_infos)
    end
    render json: array
  end

  ##
  # deprecated someday
  def moes
    moes_info = {}

    result_set = @experiment.result_names
    result_set = if result_set.blank?
      [t('experiments.analysis.no_results')]
    else
      result_set.map{|x| [Experiment.output_parameter_label_for(x), x, "moes_parameter"]}
    end

    moes_and_params = get_moes_and_params(result_set)

    # params = if done_run.nil?
    #           [ [t('experiments.analysis.no_completed_runs'), nil] ]
    #         else
    #           done_run.arguments.split(',').map{|x|
    #             [@experiment.input_parameter_label_for(x), x]}
    #         end


    #TODO Unsafety behaviour, inject code???
    moes_info[:moes] = result_set.map{ |label, id|
      "<option value='#{id}'>#{label}</option>" }.join

    moes_info[:moes_and_params] = moes_and_params.map{ |label, id, type|
      "<option data-type='#{type}' value='#{id}'>#{label}</option>" }.join

    moes_info[:params] = params.map{ |label, id|
      "<option value='#{id}'>#{label}</option>" }.join


    if @experiment.simulation_runs.first != nil
      moes_info[:moes_types] = extract_types_for_moes_parameters_from_string_values
      moes_info[:inputs_types] = extract_types_for_input_parameters
      moes_info[:moes_names] = @experiment.result_names
      moes_info[:inputs_names] = @experiment.simulation_runs.first.arguments.split(",")
    end

    #TODO add new map for histogram to improve selector
    #array_for_moes_types.insert(0,'---')

    render json: moes_info

  end

  #TODO Move this method to gem utils
  def extract_types_for_input_parameters
    first_line_inputs = @experiment.simulation_runs.first.values.split(",")
    array_for_inputs_types = []

    first_line_inputs.each{|x|
      item = x
      a = item.to_i
      b = item.to_f

      if x.eql?a.to_s
        array_for_inputs_types.push("integer")
      elsif x.eql?b.to_s
        array_for_inputs_types.push("float")
      elsif x.is_a? String
        array_for_inputs_types.push("string")
      else
        array_for_inputs_types.push("undefined")
      end

    }

    array_for_inputs_types
  end

  #TODO Move this method to gem utils
  def extract_types_for_moes_parameters_from_string_values
    first_line_result = @experiment.simulation_runs.first.result
    array_for_moes_types = []

    first_line_result.each{|x|
      item = x[1]
      if item.is_a? Integer
        array_for_moes_types.push("integer")
      elsif item.is_a? Float
        array_for_moes_types.push("float")
      elsif item.is_a? String
        array_for_moes_types.push("string")
      else
        array_for_moes_types.push("undefined")
      end
    }

    array_for_moes_types
  end

  def get_moes_and_params(result_set)
    done_run_query_condition = {is_done: true, is_error: {'$exists' => false}}
    done_run = @experiment.simulation_runs.where(done_run_query_condition,
                                                 {limit: 1, fields: %w(arguments)}).first

    moes_and_params = if done_run.nil?
                        [[t('experiments.analysis.no_completed_runs'), "nil"]]
                      else
                        done_run.arguments.split(',').map { |x|
                          [@experiment.input_parameter_label_for(x), x, "input_parameter"] } +
                            [%w(----------- nil)] + result_set
                      end
  end

  def results_info
    render json: {results: @experiment.results, error_reason: @experiment.error_reason}
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
    validate(
        param_name: :security_default,
    )

    parameter_uid = params[:param_name]
    param_doc = @experiment.get_parameter_doc(parameter_uid)
    if param_doc.nil?
      raise ValidationError.
                new(:param_name, parameter_uid, 'No such parameter in experiment')
    end

    param_type = param_doc['type'].to_sym

    validate(
        range_min: [param_type],
        range_max: [param_type],
        range_step: [param_type] #, :positive] #this validation was moved to validate_input_extension function
    )

    convert_fun = (param_type == :integer ? :to_i : :to_f)
    @range_min = params[:range_min].send(convert_fun)
    @range_max = params[:range_max].send(convert_fun)
    @range_step = params[:range_step].send(convert_fun)

    validate_input_extension(@range_min, @range_max, @range_step)

    Rails.logger.debug("New range values: #{@range_min} --- #{@range_max} --- #{@range_step}")
    #One value extend, take range_min
    if (@range_step == 0)
      new_parameter_values = Array.wrap(@range_min)
    else
      new_parameter_values = @range_min.step(@range_max, @range_step).to_a
    end
    #@priority = params[:priority].to_i
    Rails.logger.debug("New parameter values: #{new_parameter_values}")

    # locking any start and complete simulation run operations for this experiment
    Scalarm::MongoLock.mutex("experiment-#{@experiment.id}-simulation-start") do
      Scalarm::MongoLock.mutex("experiment-#{@experiment.id}-simulation-complete") do
        @num_of_new_simulations = @experiment.add_parameter_values(parameter_uid, new_parameter_values)
        @experiment.save
        @experiment.extend_progress_bar if @num_of_new_simulations > 0

        File.delete(@experiment.file_with_ids_path) if File.exist?(@experiment.file_with_ids_path)
      end
    end

    respond_to do |format|
      format.js { render partial: 'extend_input_values' }
    end
  end

  def validate_input_extension(range_min, range_max, range_step)
    unless range_min <= range_max
      raise ValidationError.
                new('range_min', range_min, "Range minimum is greater than maximum")
    end

  #to add one point (example => min: 2, max: 3, step: 5 gives [2] as single point) need to remove this, it works the same in creation of experiment
=begin
    unless range_step <= (range_max-range_min)
      raise ValidationError.
                new('range_max', range_min, "Range step is too large")
    end
=end

    #when range_step == 0 create one point (range_min)
    unless range_step >= 0
      raise ValidationError.
                new('range_step', range_step, "Range step cannot be negative")
    end

  end

  def running_simulations_table
  end

  def completed_simulations_table
  end

  def intermediate_results
    validate(
        simulations: :security_default
    )

    unless @experiment.parameters.blank?
      arguments = @experiment.parameters.flatten

      results = if params[:simulations] == 'running'
                  @experiment.simulation_runs.where(to_sent: false, is_done: false)
                elsif params[:simulations] == 'completed'
                  @experiment.simulation_runs.where(is_done: true)
                end

      result_column = if params[:simulations] == 'running'
                        'tmp_result'
                      elsif params[:simulations] == 'completed'
                        'result'
                      end

      results = results.map do |simulation_run|
        unless simulation_run.sent_at and simulation_run.index and simulation_run.values
          next
        end

        if (params[:simulations] == 'completed') and simulation_run.done_at.nil?
          next
        end

        split_values = simulation_run.values.split(',')
        modified_values = @experiment.range_arguments.reduce([]){|acc, param_uid| acc << split_values[arguments.index(param_uid)]}
        time_column = if params[:simulations] == 'running'
                        simulation_run.sent_at.nil? ? 'N/A' : simulation_run.sent_at.strftime('%Y-%m-%d %H:%M')
                      elsif params[:simulations] == 'completed'
                        (simulation_run.sent_at.nil? or simulation_run.done_at.nil?) ? 'N/A' : "#{simulation_run.done_at - simulation_run.sent_at} [s]"
                      end

        [
            simulation_run.index,
            time_column,
            simulation_run.send(result_column.to_sym).to_s || 'No data available',
            modified_values
        ].flatten
      end

      render json: { 'aaData' => results }.as_json
    else
      render json: { 'aaData' => [] }.as_json
    end
  end

  def change_scheduling_policy
    validate(
        scheduling_policy: :security_default
    )

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
      raise SecurityError.new(t('experiments.destroy.failure')) unless @experiment.user_id == current_user.id
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

      simulation_to_send = nil

      Scalarm::MongoLock.mutex("experiment-#{@experiment.id}-simulation-start") do
        simulation_to_send = @experiment.completed? ? nil : @experiment.get_next_instance
        unless sm_user.nil? or simulation_to_send.nil?
          simulation_to_send.sm_uuid = sm_user.sm_uuid
          simulation_to_send.save
        end
      end

      if simulation_to_send
        Rails.logger.info("Next simulation run for experiment #{@experiment.id} is: #{simulation_to_send.index}")
        # TODO adding caching capability to the experiment object
        #simulation_to_send.put_in_cache
        @experiment.progress_bar_update(simulation_to_send.index, 'sent')

        simulation_doc.merge!({'status' => 'ok', 'simulation_id' => simulation_to_send.index,
                   'execution_constraints' => { 'time_constraint_in_sec' => @experiment.time_constraint_in_sec },
                   'input_parameters' => Hash[simulation_to_send.arguments.split(',').zip(simulation_to_send.values.split(','))] })
      else
        Rails.logger.debug('next_simulation: Simulation to send is nil!')
        if @experiment.supervised and not @experiment.completed?
          simulation_doc.merge!({'status' => 'wait', 'reason' => 'There is no more simulations',
                                 'duration_in_seconds' => 2})
        else
          simulation_doc.merge!({'status' => 'all_sent', 'reason' => 'There is no more simulations'})
        end
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
    validate(
        moe_name: [:optional, :security_default]
    )

    resolution = params[:resolution].to_i
    moe_type= params[:type]
    if params[:moe_name].blank? or not resolution.between?(1,100)
      render inline: ""
    else
      @chart = HistogramChart.new(@experiment, params[:moe_name], resolution, moe_type)
      @visible_threshold_resolution = 15
    end
  end

  ##
  # GET Params:
  # - x_axis
  # - y_axis
  # - container_id
  # - x_axis_type
  # - y_axis_type
  def scatter_plot
    validate(
        x_axis: [:optional, :security_default],
        y_axis: [:optional, :security_default],
        x_axis_type: [:optional, :security_default],
        y_axis_type: [:optional, :security_default],
        container_id: [:optional, :security_default]
    )
    if params[:x_axis].blank? or params[:y_axis].blank?
      render inline: ""
    else
      @chart = ScatterPlotChart.new(
          @experiment,
          params[:x_axis].to_s,
          params[:y_axis].to_s,
          params[:type_of_x],
          params[:type_of_y],
          x_axis_type: params[:x_axis_type].to_s,
          y_axis_type: params[:y_axis_type].to_s,

      )
      Rails.logger.debug("ScatterPlotChart --- x axis: #{@chart.x_axis}, y axis: #{@chart.y_axis}")
      @chart.prepare_chart_data
      @uuid = SecureRandom.uuid
      @container_id = params[:container_id] || "bivariate_chart_#{@uuid}"
    end
  end

  def scatter_plot_series
    if params[:x_axis].blank? or params[:y_axis].blank? or params[:x_axis]=="nil"
      render inline: ""
    else
      @chart = ScatterPlotChart.new(@experiment, params[:x_axis].to_s, params[:y_axis].to_s, params[:type_of_x].to_s, params[:type_of_y].to_s)
      Rails.logger.debug("New series for scatter plot --- x axis: #{@chart.x_axis}, y axis: #{@chart.y_axis}")
      @chart.prepare_chart_data
      render json: @chart.chart_data
    end
  end

  def regression_tree
    validate(
        moe_name: [:optional, :security_default]
    )

    if params[:moe_name].blank?
      render inline: ""
    else
      @chart = RegressionTreeChart.new(@experiment, params[:moe_name], Rails.configuration.r_interpreter)
      @chart.prepare_chart_data
    end
  end

  def parameter_values
    validate(
        param_name: :security_default
    )


    @parameter_uid = params[:param_name]

    @parameter_uid, @parametrization_type = @experiment.parametrization_of(@parameter_uid)

    @param_type = {}
    @param_type['type'] = @parametrization_type
    @param_values = @experiment.generated_parameter_values_for(@parameter_uid)
  end

=begin
@api {get} /experiments/:id/simulation_manager Get SimulationManager Code package including SiM App, Config, etc.
@apiName GetSimulationManager
@apiGroup Experiments
=end
  def simulation_manager
    sm_uuid = SecureRandom.uuid
    # prepare locally code of a simulation manager to download with a configuration file
    InfrastructureFacade.prepare_simulation_manager_package(sm_uuid, current_user.id, @experiment.id.to_s) do |path|
      contents = File.open(path) {|f| f.read}
      send_data contents,
                filename: File.basename(path),
                type: 'application/zip'
    end
  end

  def share
    validate(
        mode: :security_default,
        id: :security_default
    )

    @experiment, @user = nil, nil

    if (not params.include?('sharing_with_login')) or (@user = ScalarmUser.find_by_login(params[:sharing_with_login].to_s)).blank?
      flash[:error] = t('experiments.user_not_found', { user: params[:sharing_with_login] })
    end

    experiment_id = BSON::ObjectId(params[:id])

    if (@experiment = Experiment.find_by_query({ '$and' => [{ _id: experiment_id }, { user_id: current_user.id } ]})).blank?
      flash[:error] = t('experiments.not_found', { id: params[:id], user: params[:sharing_with_login] })
    end

    unless flash[:error].blank?

      redirect_to action: :index
    else
      # TODO use Experiment.share method
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

  def update
    if @experiment.user_id != current_user.id
      flash[:error] = t('experiments.edit.failure')
    else
      @experiment.name = params[:experiment][:name]
      @experiment.description = params[:experiment][:description]

      @experiment.save
      flash[:notice] = t('experiments.edit.success')
    end

    redirect_to experiment_path(@experiment.id)
  end

  def new
    @simulation_input = @simulation.input_specification
  end

  # getting id of a random running experiment
  def random_experiment
    @running_experiments = if not current_user.nil?
      current_user.get_running_experiments
    elsif not sm_user.nil?
      sm_user.scalarm_user.get_running_experiments
    else
      []
    end

    if (experiment = @running_experiments.sample).nil?
      render inline: '', status: 404
    else
      render inline: experiment.id.to_s
    end
  end

  def results_binaries
    storage_manager_url = InformationService.instance.sample_public_url 'storage_managers'
    redirect_to LogBankUtils::experiment_url(storage_manager_url,
                                             @experiment.id, current_user)
  end

  # POST params:
  # - point - JSON Hash with parameter space point
  def schedule_point
    validate(
        point: :security_json
    )

    custom_experiment = (@experiment.type == 'manual_points')
    raise ValidationError.
              new(:id, @experiment.id, 'Not a custom-points experiment') unless custom_experiment

    @experiment.add_point!(Utils::parse_json_if_string(params[:point]))

    respond_to do |format|
      format.json { render json: {status: 'ok'}, status: :ok }
    end
  end

  # GET params:
  # - point - JSON Hash with parameter space point
  def get_result
    validate(
        point: :security_json
    )

    result = @experiment.get_result_for(Utils::parse_json_if_string(params[:point]))

    respond_to do |format|
      format.json do
        if result
          render json: {status: 'ok', result: result}
        else
          render json: {status: 'error', message: 'Point not found'}
        end
      end
    end
  end

=begin
  @api {post} /experiments/:id/mark_as_complete.json Mark as Complete
  @apiName mark_as_complete
  @apiGroup Experiments
  @apiDescription This action allows user to mark experiment as complete and upload its results

  @apiParam {String} id Unique id of experiment on which action will be performed
  @apiParam {json} [results] Results of experiment
  @apiParam {string} [results.values] CSV representation of input space final coordinates of result
  @apiParam {String} [status] Status of experiment; allowed values: ['error', 'ok']
  @apiParam {String} [reason] Description of error

  @apiParamExample Params-with-result
    results:
      {
        "key": "value"
        "foo": "bar"
        "baz": 42
      }

  @apiParamExample Params-with-error
    status: 'error'
    reason: 'Supervisor script has died'

  @apiSuccess {Object} info json object with information about performed action
  @apiSuccess {String} info.status status of performed action, on success always 'ok'

  @apiSuccessExample {json} Success-Response
    {
      'status': 'ok'
    }
=end
  def mark_as_complete
    validate(
        results: [:optional, :security_json],
        status: [:optional, :security_default],
        reason: [:optional, :string]
    )
    raise ValidationError.
              new(:id, @experiment.id, 'Not a supervised experiment') unless @experiment.supervised

    if params.include?(:status) and params[:status] == 'error'
      @experiment.is_error = true
      @experiment.error_reason = params[:reason] if params.include?(:reason)
    elsif params.include?(:results)
      @experiment.mark_as_complete! Utils::parse_json_if_string(params[:results])
    end
    @experiment.save
    render json: {status: 'ok'}
  end

  require 'scalarm/service_core/token_utils'

  ##
  # Search avaliable supervisors (scripts) using InformationService
  # and available ExperimentSupervisors
  def get_supervisor_ids(es_url)
    # TODO SCAL-770 there can be many ES instances - get all supervisors from them
    # TODO ES development (http)?
    supervisors = []

    if es_url.blank?
      Rails.logger.error('There are no Experiment Supervisors available')
    else
      begin
        Rails.logger.error('[supervisor_options] Using Experiment Supervisor:' + es_url)
        supervisors_resp = current_user.get_with_token("https://#{es_url}/supervisors")
        supervisors = JSON.parse(supervisors_resp)
      rescue RestClient::Exception, StandardError => e
        Rails.logger.error "Unable to connect with Supervisor: #{e.to_s}"
      end
    end

    supervisors
  end

  helper_method :get_supervisor_ids

  private

  def transform_experiment(experiment)
    if experiment.supervised
      SupervisedExperiment.from_experiment(experiment)
    elsif experiment.type == 'manual_points'
      CustomPointsExperiment.from_experiment(experiment)
    else
      experiment
    end
  end

  def load_experiment
    validate(
        id: [:optional, :security_default]
    )

    @experiment = nil

    if params.include?(:id)
      experiment_id = BSON::ObjectId(params[:id].to_s)

      if not current_user.nil?
        @experiment = current_user.experiments.where(id: experiment_id).first

        if @experiment.nil?
          flash[:error] = t('experiments.not_found', { id: experiment_id, user: current_user.login })
        end

      elsif (not sm_user.nil?)
        @experiment = sm_user.scalarm_user.experiments.where(id: experiment_id).first

        if @experiment.nil?
          flash[:error] = t('security.sim_authorization_error', sm_uuid: sm_user.sm_uuid, experiment_id: params[:id])
          Rails.logger.error(flash[:error])
        end
      end

      if @experiment.nil?
        respond_to do |format|
          format.html { redirect_to action: :index }
          format.json { render json: { status: 'error', reason: flash[:error] }, status: 403 }
        end
      else
        @experiment = transform_experiment @experiment
      end
    end
  end

  def load_simulation
    validate(
        simulation_id: [:optional, :security_default],
        simulation_name: [:optional, :security_default]
    )

    @simulation = if params['simulation_id']
                    current_user.simulation_scenarios.where(id: BSON::ObjectId(params['simulation_id'].to_s)).first
                  elsif params['simulation_name']
                    current_user.simulation_scenarios.where(name: params['simulation_name'].to_s).first
                  else
                    nil
                  end

    if @simulation.nil?
      flash[:error] = t('simulation_scenarios.not_found', { id: (params['simulation_id'] or params['simulation_name']),
                        user: current_user.login })

      respond_to do |format|
        format.html { redirect_to action: :index }
        format.json { render json: { status: 'error', reason: flash[:error] }, status: 403 }
      end
    end
  end

  def input_space_manual_specification(experiment)
    # TODO , :experiment_input
    validate(
        doe: :security_json
    )

    doe_info = params['doe'].blank? ? [] : Utils.parse_json_if_string(params['doe']).delete_if { |_, parameters| parameters.first.nil? }

    experiment.doe_info = doe_info
    experiment.experiment_input = Experiment.prepare_experiment_input(@simulation,
                                                                      Utils.parse_json_if_string(params['experiment_input']),
                                                                      experiment.doe_info)
  end

  def input_space_imported_specification(experiment)
    are_csv_parameters_not_valid = true

    unless params[:parameter_space_file].blank?
      parameters_to_include = params.keys.select { |parameter|
        parameter.start_with?('param_') and params[parameter] == '1'
      }.map { |parameter| parameter.split('param_').last }

      unless parameters_to_include.blank?

        importer = ExperimentCsvImporter.new(Utils.read_if_file(params[:parameter_space_file]), parameters_to_include)

        are_csv_parameters_not_valid = importer.parameters.any? do |param_uid|
          not @simulation.input_parameters.include?(param_uid)
        end
      end
    end

    if are_csv_parameters_not_valid
      flash[:error] = t('experiments.import.csv_parameters_not_valid')
    else
      experiment.doe_info = [ [ 'csv_import', importer.parameters, importer.parameter_values ] ]
      experiment.experiment_input = Experiment.prepare_experiment_input(@simulation, {}, experiment.doe_info)
    end
  end

end
