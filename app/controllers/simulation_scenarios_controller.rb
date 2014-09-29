require 'zip'

class SimulationScenariosController < ApplicationController
  before_filter :load_simulation_scenario, except: [ :index, :create ]

  def index

  end

  def edit
    if @simulation_scenario.blank? or @simulation_scenario.user_id != @current_user.id
      flash[:error] = t('simulation_scenarios.not_owned_by', id: params[:id], user: @current_user.login)
      redirect_to simulations_path
    else
      @input_writers = SimulationInputWriter.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}.unshift(["None", nil])
      @executors = SimulationExecutor.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}.unshift(["None", nil])
      @output_readers = SimulationOutputReader.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}.unshift(["None", nil])
      @progress_monitors = SimulationProgressMonitor.find_all_by_user_id(@current_user.id).map{|ex| [ex.name, ex._id]}.unshift(["None", nil])
    end
  end

  def update
    if @simulation_scenario.blank? or @simulation_scenario.user_id != @current_user.id
      flash[:error] = t('simulation_scenarios.not_owned_by', id: params[:id], user: @current_user.login)
    else
      simulation_input =  params.include?(:simulation_input) ? Utils.parse_json_if_string(Utils.read_if_file(params[:simulation_input])) : nil
      simulation_scenario_params_validation(simulation_input)

      # simulation update
      if flash[:error].nil?
        @simulation_scenario.name = params[:simulation_name]
        @simulation_scenario.description = params[:simulation_description]
        @simulation_scenario.input_specification = simulation_input unless simulation_input.blank?
        @simulation_scenario.created_at = Time.now

        begin
          set_up_adapter('input_writer', @simulation_scenario, false)
          set_up_adapter('executor', @simulation_scenario)
          set_up_adapter('output_reader', @simulation_scenario, false)
          set_up_adapter('progress_monitor', @simulation_scenario, false)

          unless (binaries = params[:simulation_binaries]).blank?
            @simulation_scenario.set_simulation_binaries(binaries.original_filename, binaries.read)
          end

          @simulation_scenario.save

          flash[:notice] = t('simulation_scenarios.update.success', name: @simulation_scenario.name) if flash[:error].nil?
        rescue Exception => e
          Rails.logger.error("Exception occurred : #{e}")
        end
      end
    end

    respond_to do |format|
      format.json { render json: { status: (flash[:error].nil? ? 'ok' : 'error'), simulation_id: simulation.id.to_s } }
      format.html { redirect_to simulations_path }
    end
  end

  def create
  end

  def show
    render json: (
        if @simulation_scenario
          {status: 'ok', data: @simulation_scenario.to_h }
        else
          {status: 'error', error_code: 'not_found'}
        end
    )
  end

  def code_base
    if @simulation_scenario.blank?
      render inline: t('simulation_scenarios.not_found', id: params[:id]), status: 404
    else
      code_base_dir = Dir.mktmpdir('code_base')

      file_list = %w(input_writer executor output_reader progress_monitor)
      file_list.each do |filename|
        unless @simulation_scenario.send(filename).nil?
          IO.write("#{code_base_dir}/#{filename}", @simulation_scenario.send(filename).code)
        end
      end
      IO.binwrite("#{code_base_dir}/simulation_binaries.zip", @simulation_scenario.simulation_binaries)
      file_list << 'simulation_binaries.zip'

      IO.binwrite("#{code_base_dir}/input.json", @simulation_scenario.input_specification.to_json)
      file_list << 'input.json'

      zipfile_name = File.join('/tmp', "simulation_scenario_#{@simulation_scenario.id}_code_base.zip")

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
  end

  def destroy
    if @simulation_scenario.blank?
      render inline: t('simulation_scenarios.not_found', id: params[:id]), status: 404
    else
      flash[:notice] = t('simulations.destroy', name: @simulation_scenario.name)
      @simulation_scenario.destroy
    end

    redirect_to simulations_path
  end

  def share
    @user = nil

    if (not params.include?('sharing_with_login')) or (@user = ScalarmUser.find_by_login(params[:sharing_with_login])).blank?
      flash[:error] = t('experiments.user_not_found', { user: params[:sharing_with_login] })
    end

    if @simulation_scenario.blank? or @simulation_scenario.user_id != @current_user.id
      flash[:error] = t('simulation_scenarios.not_owned_by', { id: params[:id], user: params[:sharing_with_login] })
    end

    if flash[:error].blank?
      if ['share', 'unshare'].include?(params[:mode])
        sharing_list = @simulation_scenario.shared_with
        sharing_list = [ ] if sharing_list.nil?
        if params[:mode] == 'unshare'
          sharing_list.delete_if{|x| x == @user.id}
        else
          sharing_list << @user.id
        end

        @simulation_scenario.shared_with = sharing_list

      elsif ['share_with_all', 'unshare_with_all'].include?(params[:mode])
        @simulation_scenario.is_public = (params[:mode] == 'share_with_all')
      end

      @simulation_scenario.save

      flash[:notice] = t("simulation_scenarios.edit.share.#{params[:mode]}", { name: @simulation_scenario.name, user: @user.login })
    end

    if @simulation_scenario.blank?
      redirect_to simulations_path
    else
      redirect_to edit_simulation_scenario_path(@simulation_scenario.id)
    end
  end

  private

  def set_up_adapter(adapter_type, simulation, mandatory = true)
    if params.include?(adapter_type + '_id')
      adapter_id = params[adapter_type + '_id']
      adapter = Object.const_get("Simulation#{adapter_type.camelize}").find_by_id(adapter_id)

      if not adapter.nil? and adapter.user_id == @current_user.id
        simulation.send(adapter_type + '_id=', adapter.id)
      else
        if mandatory
          flash[:error] = t('simulations.create.adapter_not_found', {adapter: adapter_type.camelize, id: adapter_id})
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
        flash[:error] = t('simulations.create.mandatory_adapter', {adapter: adapter_type.camelize, id: adapter_id})
        raise Exception("Setting up Simulation#{adapter_type.camelize} is mandatory")
      end
    end
  end

  def simulation_scenario_params_validation(simulation_input)
    case true
      when (not simulation_input.blank?)
        begin
          Utils.parse_json_if_string(simulation_input)
        rescue
          flash[:error] = t('simulations.create.bad_simulation_input')
        end

      when (not (scenarios = Simulation.where({name: params[:simulation_name], user_id: @current_user.id})).blank?)
        unless scenarios.size == 1 and scenarios.first.id == @simulation_scenario.id
          flash[:error] = t('simulations.create.simulation_invalid_name')
        end
    end
  end

  private

  def load_simulation_scenario
    users_scenarios = @current_user.get_simulation_scenarios

    @simulation_scenario = if params[:id]
                             users_scenarios.find{|scenario| scenario.id.to_s == params[:id]}
                           elsif
                             users_scenarios.find{|scenario| scenario.id.to_s == params[:name]}
                           else
                             nil
                           end
  end
end
