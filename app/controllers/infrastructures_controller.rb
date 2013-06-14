class InfrastructuresController < ApplicationController

  def infrastructure_info
    infrastructure_info = {}

    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure|
      infrastructure_info[infrastructure_id] = infrastructure[:facade].current_state(current_user.id)
    end

    infrastructure_info[:private] = 'Not available'
    infrastructure_info[:amazon] = 'Not available'

    render json: infrastructure_info
  end

  def schedule_simulation_managers
    experiment_id = (params[:experiment_id] or nil)

    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status, response_msg = infrastructure.start_simulation_managers(current_user, params[:job_counter].to_i, experiment_id, params)

    render json: { status: status, msg: response_msg }
  end

  def add_infrastructure_credentials
    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status = infrastructure.add_credentials(current_user, params, session)

    render json: { status: status }
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