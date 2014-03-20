
class InfrastructuresController < ApplicationController

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
      long_cloud_name = CloudFactory.full_name(cloud_name)

      img_secrets.destroy
      msg = I18n.t('infrastructures_controller.image_removed', cloud_name: long_cloud_name, image_id: image_id)
      render json: { status: 'ok', msg: msg, cloud_name: long_cloud_name, image_id: image_id }
    else
      msg = I18n.t('infrastructures_controller.image_not_found')
      render json: { status: 'error', msg: msg }
    end
  end

  def remove_private_machine_creds
    machine_creds = PrivateMachineCredentials.find_by_id(params[:private_machine_creds_id])
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

  def remove_credentials
    secrets = CloudSecrets.find_by_query('cloud_name'=>params[:cloud_name], 'user_id'=>BSON::ObjectId(params[:user_id]))
    if secrets
      secrets.destroy
      msg = I18n.t('infrastructures_controller.credentials_removed', name: CloudFactory.full_name(params[:cloud_name]))
      render json: { status: 'ok', msg: msg }
    else
      msg = I18n.t('infrastructures_controller.credentials_not_removed', name: CloudFactory.full_name(params[:cloud_name]))
      render json: { status: 'error', msg: msg }
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