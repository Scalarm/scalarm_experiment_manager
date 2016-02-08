require 'infrastructure_facades/infrastructure_facade'
require 'infrastructure_facades/cluster_worker_delegate'

# Methods necessary to implement by subclasses:

# - add_credentials(user, params, session) -> credentials record [MongoActiveRecord] - save credentials to database
#  -- all params keys are converted to symbols and values are stripped
# - remove_credentials(record_id, user_id, params) - remove credentials for this infrastructure (e.g. user credentials)
# - get_credentials(user_id, params) - show collection of credentials records for this infrastructure

# Methods which can be overriden, but not necessarily:
# - default_additional_params() -> Hash - default additional parameters necessary to start Simulation Managers with the facade
# - init_resources() - initialize resources needed to perform operations on Simulation Managers
#   -- this method will be invoked before executing yield_simulation_manager(s) block
# - clean_up_resources() - close resources needed to perform operations on Simulation Managers
#   -- this method will be invoked after executing yield_simulation_manager(s) block
# - create_simulation_manager(record) - create SimulationManager instance on SMRecord base
#   -- typically you will not override this method, but sometimes custom SimulationManager is needed
#   -- this method should not be used directly
# - _simulation_manager_before_monitor(record) - executed before monitoring single resource
# - _simulation_manager_after_monitor(record) - executed after monitoring single resource
# - destroy_unused_credentials(authentication_mode, user) - destroy infrastructure credentials which are not used anymore


class ClusterFacade < InfrastructureFacade
  include SharedSSH

  attr_reader :scheduler

  def initialize(cluster_record, scheduler)
    @cluster_record = cluster_record
    @scheduler = scheduler
    @worker_delegate = nil

    super()
  end

  def short_name
    if @cluster_record.nil?
      "clusters"
    else
      "cluster_#{@cluster_record.id}"
    end
  end

  def long_name
    if @cluster_record.nil?
      "clusters"
    else
      @cluster_record.name
    end
  end

  def enabled_for_user?(user_id)
    @cluster_record.visible_to?(user_id)
  end

  def query_simulation_manager_records(user_id, experiment_id, params)
    job_records = JobRecord.where(
      infrastructure_type: 'clusters',
      user_id: user_id,
      experiment_id: experiment_id
    )

    job_records
  end

  def _get_sm_records(query, params={})
    JobRecord.where(query.merge({infrastructure_type: 'clusters'})).to_a
  end

  def other_params_for_booster(user_id)
    {
      scheduler: @cluster_record.scheduler
    }
  end

  # additional_params:
  # - (:login and :password)
  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    cluster_id = additional_params[:infrastructure_name].split("_").last
    Rails.logger.debug { "Cluster id is #{cluster_id}" }

    # 1. checking if the user can schedule SiM
    credentials = get_credentials(user_id, cluster_id, additional_params)
    if not credentials.valid?
      raise InfrastructureErrors::InvalidCredentialsError.new
    end

    # 2. create instances_count SiMs
    records = (1..instances_count).map do
      # 2.a create temp pass for SiM
      sm_uuid = SecureRandom.uuid
      if SimulationManagerTempPassword.find_by_sm_uuid(sm_uuid).nil?
        SimulationManagerTempPassword.create_new_password_for(sm_uuid, experiment_id)
      end

      # 2.c create record for SiM and save it
      record = create_record(user_id, cluster_id, experiment_id, sm_uuid, additional_params)
      record.save

      record
    end

    # if additional_params[:onsite_monitoring]
    #   sm_uuid = SecureRandom.uuid
    #   InfrastructureFacade.handle_monitoring_send_errors(records) do
    #     InfrastructureFacade.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, @scheduler.short_name, additional_params)
    #   end
    # end

    records
  end

  def get_sm_record_by_id(record_id)
    JobRecord.where(id: record_id).first
  end

  def _simulation_manager_stop(record)
    self.worker_delegate(record).stop(record)
  end

  def _simulation_manager_restart(record)
    self.worker_delegate(record).restart(record)
  end

  def _simulation_manager_resource_status(record)
    self.worker_delegate(record).resource_status(record)
  end

  def _simulation_manager_running?(record)
    self.worker_delegate(record).running?(record)
  end

  def _simulation_manager_get_log(record)
    self.worker_delegate(record).get_log(record)
  end

  def _simulation_manager_resource_status(record)
    self.worker_delegate(record).resource_status(record)
  end

  def _simulation_manager_install(record)
    self.worker_delegate(record).resource_status(record)
  end

  def _simulation_manager_prepare_resource(record)
    self.worker_delegate(record).prepare_resource(record)
  end

  def add_credentials(user, params, session)
  end

  def remove_credentials(record_id, user_id, params)
  end

  def get_credentials(user_id, params)
  end


  #### private ####

  def get_credentials(user_id, cluster_id, request_params)
    credentials = if not request_params[:login].blank? and not request_params[:password].blank?
                    Rails.logger.debug { "Creade temp credentials with password" }
                    ClusterCredentials.create_password_credentials(
                      user_id, cluster_id, request_params[:login], request_params[:password]
                    )
                  elsif request_params.include?(:priv_key)
                    Rails.logger.debug { "Creade temp credentials with privkey" }
                    ClusterCredentials.create_privkey_credentials(
                      user_id, cluster_id, request_params[:priv_key]
                    )
                  else
                    Rails.logger.debug { "finding existing " }
                    ClusterCredentials.where(owner_id: user_id, cluster_id: cluster_id).first
                  end

    if credentials.nil?
      raise InfrastructureErrors::NoCredentialsError.new
    end

    credentials
  end

  # params: (string keys)
  # - time_limit
  # - start_at
  # - grant_id (optional)
  # - nodes (optional)
  # - ppn (optional)
  # - queue (optional)
  # - onsite_monitoring (optional) - monitoring will be enabled if onsite_monitoring is not blank
  def create_record(user_id, cluster_id, experiment_id, sm_uuid, params)
    job = JobRecord.new(
        infrastructure_type: 'clusters',
        infrastructure_identifier: "cluster_#{cluster_id}",
        user_id: user_id,
        experiment_id: experiment_id,
        sm_uuid: sm_uuid,
        infrastructure: short_name,
        created_at: Time.now
    )

    job.time_limit = params.include?('time_limit') ? params['time_limit'].to_i : 60
    job.start_at = params['start_at']
    job.grant_identifier = params['grant_identifier'] unless params['grant_identifier'].blank?
    job.nodes = params['nodes'] unless params['nodes'].blank?
    job.ppn = params['ppn'] unless params['ppn'].blank?
    job.queue_name = params['queue'] unless params['queue'].blank?
    job.memory = params['memory'].to_i unless params['memory'].blank?

    job.initialize_fields

    job.onsite_monitoring = if params['onsite_monitoring'] == true  then true else false end

    job
  end

  def self.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, scheduler_name, params={})
   # TODO: implement multiple architectures support
   arch = 'linux_x86'

   InfrastructureFacade.prepare_monitoring_config(sm_uuid, user_id, [{name: scheduler_name}])

   credentials.ssh_session do |ssh|
     credentials.scp_session do |scp|
       PlGridFacade.remove_remote_monitoring_files(ssh)
       SSHAccessedInfrastructure::create_remote_directories(ssh)

       PlGridFacade.upload_monitoring_files(scp, sm_uuid, arch)
       PlGridFacade.remove_local_monitoring_config(sm_uuid)

       cmd = PlGridFacade.start_monitoring_cmd
       Rails.logger.info("Executing scalarm_monitoring for user #{user_id}: #{cmd}")
       output = ssh.exec!(cmd)
       Rails.logger.info("Output: #{output}")
     end
   end
 end

 def worker_delegate(sm_record)
   facade = InfrastructureFacadeFactory.get_facade_for(sm_record.infrastructure_identifier)
   @worker_delegate ||= ClusterWorkerDelegate.create_delegate(sm_record, facade)
   @worker_delegate
 end

end