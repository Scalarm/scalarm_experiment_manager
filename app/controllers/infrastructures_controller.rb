class InfrastructuresController < ApplicationController

  def infrastructure_info
    collect_infrastructure_info

    render json: @infrastructure_info
  end

  def schedule_simulation_managers
    user = User.find(params[:user_id])
    experiment_id = (params[:experiment_id] or nil)

    infrastructure = InfrastructureFacade.get_facade_for(params[:infrastructure_type])
    status, response_msg = infrastructure.start_simulation_managers(user, params[:job_counter].to_i, experiment_id)

    render json: {status: status, msg: response_msg}
  end

  # ============================ PRIVATE METHODS ============================
  private

  def collect_infrastructure_info
    Rails.logger.debug('Accessing private infrastructure info')
    @infrastructure_info = {}
    private_all_machines = SimulationManagerHost.all.count
    private_idle_machines = SimulationManagerHost.select { |x| x.state == 'not_running' }.count

    @infrastructure_info[:private] = "Currently #{private_idle_machines}/#{private_all_machines} machines are idle."

    user_id = session[:user]
    return if user_id.nil?
    Rails.logger.debug('Accessing PL-Grid information')

    plgrid_jobs = PlGridJob.find_by_user_id(user_id).count
    @infrastructure_info[:plgrid] = "Currently #{plgrid_jobs} jobs are running."
    # amazon_instances = (defined? @ec2_running_instances) ? @ec2_running_instances.size : 0
    #amazon_instances = CloudMachine.where(:user_id => user_id).count
    #
    #@infrastructure_info[:amazon] = "Currently #{amazon_instances} Virtual Machines are running."
  end
end