require 'infrastructure_facades/tree_utils'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructuresController < ApplicationController
  include InfrastructureErrors

  def index
    render 'infrastructure/index'
  end

  # GET a root of Infrastructures Tree. This method is used directly by javascript tree.
  def tree
    data = {
      name: 'Scalarm',
      type: TreeUtils::TREE_ROOT,
      children: tree_infrastructures
    }

    render json: data
  end

  # Get JSON data for build a base tree for Infrastructure Tree _without_ Simulation Manager
  # nodes. Starting with non-cloud infrastructures and cloud infrastructures, leaf nodes
  # are fetched recursivety with tree_node methods of every concrete facade.
  # This method is used by tree method.
  def tree_infrastructures
    [
      *(InfrastructureFacade.non_cloud_infrastructures.values.map do |inf|
        inf[:facade].to_hash
      end),
      {
        name: 'Clouds',
        type: TreeUtils::TREE_META,
        children:
          InfrastructureFacade.cloud_infrastructures.values.map do |inf|
            inf[:facade].to_hash
          end
      }
    ]
  end

  # Get Simulation Manager nodes for Infrastructure Tree for given containter name
  # and current user.
  # GET params:
  # - name: name of Infrastructure
  # - attrs: additional attributes
  def sm_nodes
    begin
      facade = InfrastructureFacade.get_facade_for(params[:infrastructure_name])
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

    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure|
      infrastructure_info[infrastructure_id] = infrastructure[:facade].current_state(@current_user.id)
    end

    infrastructure_info[:private] = 'Not available'
    infrastructure_info[:amazon] = 'Not available'

    render json: infrastructure_info
  end

  def schedule_simulation_managers
    experiment_id = (params[:experiment_id] or nil)

    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status, response_msg = infrastructure.start_simulation_managers(@current_user, params[:job_counter].to_i, experiment_id, params)

    render json: { status: status, msg: response_msg }
  end

  def add_infrastructure_credentials
    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status = infrastructure.add_credentials(@current_user, params, session)

    render json: { status: status, msg: I18n.t("#{params[:infrastructure_type]}.login.#{status}") }
  end

  def remove_image
    img_secrets = CloudImageSecrets.find_by_id(params[:image_secrets_id])
    if img_secrets and img_secrets.user_id != @current_user.id
      render json: { status: 'error', msg: I18n.t('infrastructures_controller.permission_denied') }
    end

    if img_secrets
      cloud_name = img_secrets.cloud_name
      image_id = img_secrets.image_id
      long_cloud_name = CloudFactory.long_name(cloud_name)

      img_secrets.destroy
      msg = I18n.t('infrastructures_controller.image_removed', cloud_name: long_cloud_name, image_id: image_id)
      render json: { status: 'ok', msg: msg, cloud_name: long_cloud_name, image_id: image_id }
    else
      msg = I18n.t('infrastructures_controller.image_not_found')
      render json: { status: 'error', msg: msg }
    end
  end

  def remove_private_machine_credentials
    machine_creds = PrivateMachineCredentials.find_by_id(params[:credentials_id])
    if machine_creds and machine_creds.user_id != @current_user.id
      render json: { status: 'error', msg: I18n.t('infrastructures_controller.permission_denied') }
    end

    if machine_creds
      name = machine_creds.machine_desc
      machine_creds.destroy
      msg = I18n.t('infrastructures_controller.priv_machine_creds_removed', name: name)
      render json: { status: 'ok', msg: msg }
    else
      msg = I18n.t('infrastructures_controller.priv_machine_creds_not_removed')
      render json: { status: 'error', msg: msg }
    end
  end

  # TODO: delegate to facades
  def remove_credentials
    secrets = CloudSecrets.find_by_query('cloud_name'=>params[:cloud_name], 'user_id'=>BSON::ObjectId(params[:user_id]))
    if secrets
      secrets.destroy
      msg = I18n.t('infrastructures_controller.credentials_removed', name: CloudFactory.long_name(params[:cloud_name]))
      render json: { status: 'ok', msg: msg }
    else
      msg = I18n.t('infrastructures_controller.credentials_not_removed', name: CloudFactory.long_name(params[:cloud_name]))
      render json: { status: 'error', msg: msg }
    end
  end

  def simulation_managers_info
    begin
      infrastructure_facade = if params[:infrastructure_name] == 'cloud'
                               InfrastructureFacade.get_facade_for(params[:cloud_name])
                              else
                               InfrastructureFacade.get_facade_for(params[:infrastructure_name])
                              end

      @current_state_summary = infrastructure_facade.current_state(@current_user)
      @simulation_managers = infrastructure_facade.get_sm_records(@current_user.id)

      render partial: "infrastructure/information/simulation_managers/#{params[:infrastructure_name]}"
    rescue Exception => e
      # FIXME
      render text: "An error occured: #{e.to_s}"
    end
  end

  def simulation_manager_command
    begin
      if %w(stop restart).include? params[:command]
        sm = get_simulation_manager(params[:record_id], params[:infrastructure_name])
        sm.send(params[:command])
        render json: {status: 'ok', msg: "Executed #{params[:command]} on Simulation Manager"}
      else
        render json: {status: 'error', msg: "No such command for Simulation Manager: #{params[:command]}"}
      end
    rescue NoSuchSimulationManagerError => e
      render json: { status: 'error', msg: "No such Simulation Manager" }
    rescue AccessDeniedError => e
      render json: { status: 'error', msg: "Access to Simulation Manager denied" }
    rescue Exception => e
      render json: { status: 'error', msg: "Error on fetching Simulation Manager: #{e.to_s}" }
    end
  end


  # Mandatory GET params:
  # - infrastructure_name
  # - record_id
  def get_sm_dialog
    begin
      @simulation_manager = get_simulation_manager(params['record_id'], params['infrastructure_name'])
      render inline: render_to_string(partial: 'sm_dialog')
    rescue NoSuchInfrastructureError => e
      render json: { status: 'error', msg: "No infrastructure: #{params[:infrastructure_name]}" }
    rescue NoSuchSimulationManagerError => e
      render json: { status: 'error', msg: "No such Simulation Manager" }
    rescue Exception => e
      render json: { status: 'error', msg: "Exception when getting Simulation Manager #{params['resource_id']}@#{params['sm_container']}: #{e}" }
    end
  end

  def get_simulation_manager(record_id, infrastructure_name)
    facade = InfrastructureFacade.get_facade_for(infrastructure_name)
    record = facade.get_sm_record_by_id(record_id)
    raise NoSuchSimulationManagerError if record.nil?
    raise AccessDeniedError if record.user_id.to_s != @current_user.id.to_s

    facade.create_simulation_manager(record)
  end

  # ============================ PRIVATE METHODS ============================
  private

  def collect_infrastructure_info(user_id)
    @infrastructure_info = {}

    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
      @infrastructure_info[infrastructure_id] = infrastructure_info[:facade].current_state(user_id)
    end

    #private_all_machines = SimulationManagerHost.all.count
    #private_idle_machines = SimulationManagerHost.select { |x| x.state == 'not_running' }.count
    #
    #@infrastructure_info[:private] = "Currently #{private_idle_machines}/#{private_all_machines} machines are idle."
    @infrastructure_info[:private] = 'Not available'
    @infrastructure_info[:amazon] = 'Not available'
    #
    #user_id = session[:user]
    #return if user_id.nil?
    #Rails.logger.debug('Accessing PL-Grid information')
    #
    #plgrid_jobs = PlGridJob.find_by_user_id(user_id)
    #plgrid_jobs
    #@infrastructure_info[:plgrid] = "Currently #{plgrid_jobs ||} jobs are running."
    # amazon_instances = (defined? @ec2_running_instances) ? @ec2_running_instances.size : 0
    #amazon_instances = CloudMachine.where(:user_id => user_id).count
    #
    #@infrastructure_info[:amazon] = "Currently #{amazon_instances} Virtual Machines are running."
  end
end