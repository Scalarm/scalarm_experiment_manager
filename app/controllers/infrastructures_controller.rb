class NoSuchSmContainerError < StandardError; end
class NoSuchSmError < StandardError; end

class InfrastructuresController < ApplicationController

  def index
    render 'infrastructure/index'
  end

  # GET a root of Infrastructures Tree. This method is used directly by javascript tree.
  def tree
    data = {
      name: 'Scalarm',
      type: 'root-node',
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
        type: 'meta-node',
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
  # - name: name of Simulation Manager containter
  def sm_nodes
    container = InfrastructureFacade.get_registered_sm_containters[params[:name]]
    unless container.nil?
      render json: container.sm_nodes(@current_user.id)
    else
      Rails.logger.error "Requested Simulation Managers container does not exist: #{params[:name]}"
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

      img_secrets.destroy
      msg = I18n.t('infrastructures_controller.image_removed', cloud_name: long_cloud_name, image_id: image_id)
      render json: { status: 'ok', msg: msg, cloud_name: CloudFactory.long_name(cloud_name), image_id: image_id }
    else
      msg = I18n.t('infrastructures_controller.image_not_found')
      render json: { status: 'error', msg: msg }
    end
  end

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

  def stop_sm
    begin
      get_sm_proxy(params['sm_container'], params['resource_id']).stop
      render json: { status: 'ok', msg: "Stopping Simulation Manager #{params['resource_id']}@#{params['sm_container']}..." }
    rescue NoSuchSmContainerError => e
      render json: { status: 'error', msg: "No such container: #{params['sm_container']}" }
    rescue NoSuchSmError => e
      render json: { status: 'error', msg: "No such computational resource: #{params['resource_id']}@#{params['sm_container']}" }
    rescue Exception => e
      render json: { status: 'error', msg: "Exception when stopping Simulation Manager #{params['resource_id']}@#{params['sm_container']}: #{e}" }
    end
  end

  def restart_sm
    begin
      get_sm_proxy(params['sm_container'], params['resource_id']).restart
      render json: { status: 'ok', msg: "Restarting Simulation Manager #{params['resource_id']}@#{params['sm_container']}..." }
    rescue NoSuchSmContainerError => e
      render json: { status: 'error', msg: "No such container: #{params['sm_container']}" }
    rescue NoSuchSmError => e
      render json: { status: 'error', msg: "No such computational resource: #{params['resource_id']}@#{params['sm_container']}" }
    rescue Exception => e
      render json: { status: 'error', msg: "Exception when restarting Simulation Manager #{params['resource_id']}@#{params['sm_container']}: #{e}" }
    end
  end

  # Mandatory GET params:
  # - sm_container: Simulation Manager container name
  # - resource_id: Unique ID of resource for SM (eg. vm_id)
  def get_sm_dialog
    begin
      @sm_container = get_sm_container(params['sm_container'])
      @sm = @sm_container.simulation_manager(params['resource_id'], @current_user.id)
      raise NoSuchSmError.new if @sm.nil?
      render inline: render_to_string(partial: 'sm_dialog')
    rescue NoSuchSmContainerError => e
      render json: { status: 'error', msg: "No such container: #{params['sm_container']}" }
    rescue NoSuchSmError => e
      render json: { status: 'error', msg: "No such computational resource: #{params['resource_id']}@#{params['sm_container']}" }
    rescue Exception => e
      render json: { status: 'error', msg: "Exception when getting Simulation Manager #{params['resource_id']}@#{params['sm_container']}: #{e}" }
    end
  end

  # TODO move to infrastructures facade (with exceptions)?

  # @param [String] sm_container_name Simulation Manager container name
  # @param [String] resource_id Unique ID of resource for SM (eg. vm_id)
  # @raise [NoSuchSmError]
  # @raise [NoSuchSmContainerError]
  def get_sm_proxy(sm_container_name, resource_id)
    sm = get_sm_container(sm_container_name).simulation_manager(resource_id, @current_user.id)
    if sm.nil?
      Rails.logger.error "No such computational resource: #{sm_container_name}@#{resource_id}"
      raise NoSuchSmError.new
    else
      sm
    end
  end

  def get_sm_container(sm_container_name)
    container = InfrastructureFacade.get_registered_sm_containters[sm_container_name]
    if container.nil?
      Rails.logger.error "No such simulation managers container: #{sm_container_name}"
      raise NoSuchSmContainerError.new
    else
      container
    end

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