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
    infrastructure_specific_params = {infrastructure_type: 'clusters', infrastructure_identifier: short_name}

    JobRecord.where(query.merge(infrastructure_specific_params)).to_a
  end

  def other_params_for_booster(user_id, request_params={})
    creds_available = if request_params.include?(:proxy) and @cluster_record.plgrid == true
      true
    else
      not ClusterCredentials.where(owner_id: user_id, cluster_id: @cluster_record.id, invalid: false).first.nil?
    end

    {
      scheduler: @cluster_record.scheduler,
      user_has_valid_credentials: creds_available
    }
  end

  # additional_params:
  # - (:login and :password)
  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    cluster_id = additional_params[:infrastructure_name].split("_").last

    # 1. checking if the user can schedule SiM
    credentials = load_or_create_credentials(user_id, cluster_id, additional_params)
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

    if additional_params[:onsite_monitoring]
      sm_uuid = SecureRandom.uuid
      InfrastructureFacade.handle_monitoring_send_errors(records) do
        self.class.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, "#{self.short_name}.#{@scheduler.short_name}", additional_params)
      end
    else
      SimMonitorWorker.perform_async(additional_params[:infrastructure_name].to_s, user_id.to_s)
    end

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
    creds = if params[:type].to_s == "password"
      ClusterCredentials.create_password_credentials(user.id, params[:cluster_id].to_s, params[:login].to_s, params[:password].to_s)
    elsif params[:type].to_s == "privkey"
      ClusterCredentials.create_privkey_credentials(user.id, params[:cluster_id].to_s, params[:login].to_s, params[:privkey].to_s)
    else
      nil
    end

    creds.save if not creds.nil?
  end

  def remove_credentials(record_id, user_id, params)
    ClusterCredentials.where(owner_id: user_id, id: record_id).first.destroy
  end

  def get_credentials(user_id, params)
    ClusterCredentials.where(owner_id: user_id).to_a
  end

  def simulation_manager_code(sm_record)
    sm_uuid = sm_record.sm_uuid

    Rails.logger.debug "Preparing Simulation Manager package with id: #{sm_uuid}"

    InfrastructureFacade.prepare_simulation_manager_package(sm_uuid, nil, sm_record.experiment_id, sm_record.start_at) do
      code_dir = LocalAbsoluteDir::tmp_sim_code(sm_uuid)
      FileUtils.remove_dir(code_dir, true)
      FileUtils.mkdir(code_dir)
      @scheduler.create_tmp_job_files(sm_uuid, {dest_dir: code_dir, sm_record: sm_record.to_h}) do


        FileUtils.mv(LocalAbsolutePath::tmp_sim_zip(sm_uuid), code_dir)

        Dir.chdir(LocalAbsoluteDir::tmp) do
          %x[zip #{LocalAbsolutePath::tmp_sim_code_zip(sm_uuid)} #{ScalarmDirName::tmp_sim_code(sm_uuid)}/*]
        end
        FileUtils.rm_rf(LocalAbsoluteDir::tmp_sim_code(sm_uuid))

        zip_path = LocalAbsolutePath::tmp_sim_code_zip(sm_uuid)

        if block_given?
          begin
            yield zip_path
          ensure
            FileUtils.rm_rf(zip_path)
          end
        else
          return zip_path
        end
      end
      FileUtils.remove_dir(code_dir, true)
    end

  end

  #### private ####

  def load_or_create_credentials(user_id, cluster_id, request_params)
    cluster = ClusterRecord.where(id: cluster_id).first

    credentials = if request_params.include?(:proxy) and cluster.plgrid == true
                    Rails.logger.debug { "Creade proxy based credentials" }
                    creds = GridCredentials.new(login: request_params[:login].to_s)
                    creds.secret_proxy = params[:proxy]
                    creds
                  elsif request_params[:type] == "password"
                    Rails.logger.debug { "Creade temp credentials with password" }
                    ClusterCredentials.create_password_credentials(
                      user_id, cluster_id, request_params[:login].to_s, request_params[:password].to_s
                    )
                  elsif request_params[:type] == "privkey"
                    Rails.logger.debug { "Creade temp credentials with privkey" }
                    ClusterCredentials.create_privkey_credentials(
                      user_id, cluster_id, request_params[:login].to_s, request_params[:privkey].to_s
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

    job.onsite_monitoring = if params['onsite_monitoring'] == "true"  then true else false end

    job
  end

  def self.send_and_launch_onsite_monitoring(credentials, sm_uuid, user_id, scheduler_name, params={})
    Rails.logger.debug("Sending and launching onsite monitoring: #{scheduler_name}, #{credentials}")
   # TODO: implement multiple architectures support
   arch = 'linux_amd64'

   InfrastructureFacade.prepare_monitoring_config(sm_uuid, user_id, [{name: scheduler_name}])

   credentials.ssh_session do |ssh|
     credentials.scp_session do |scp|
       PlGridFacade.remove_remote_monitoring_files(ssh)
       SSHAccessedInfrastructure::create_remote_directories(ssh)

       PlGridFacade.upload_monitoring_files(scp, sm_uuid, arch)
       PlGridFacade.remove_local_monitoring_config(sm_uuid)

       cmd = PlGridFacade.start_monitoring_cmd
       Rails.logger.info("[cluster facade] Executing scalarm_monitoring for user #{user_id}: #{cmd}")
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
