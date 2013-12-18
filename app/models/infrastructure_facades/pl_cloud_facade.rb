require 'securerandom'
require 'rest-client'

require_relative 'pl_cloud_credentials/pl_cloud_secrets'
require_relative 'pl_cloud_credentials/pl_cloud_image'

require_relative 'pl_cloud_utils/pl_cloud_client'
require_relative 'pl_cloud_utils/pl_cloud_instance'

class PLCloudFacade < InfrastructureFacade

  def current_state(user)
    # TODO
    "TODO"
  end

  def start_monitoring
    while true do
      begin
        Rails.logger.info("[plcloud] #{Time.now} - monitoring thread is working")
        plcloud_vms = PLCloudVm.all.group_by(&:user_id)

        plcloud_vms.each do |user_id, vm_list|
          user = ScalarmUser.find_by_id(user_id)
          plc_secrets = PLCloudSecrets.find_by_user_id(user.id)

          if plc_secrets.nil?
            Rails.logger.info("We cannot monitor PLCloud VMs for #{user.login} due secrets lacking")
            next
          end

          plc_client = PLCloudClient.new(plc_secrets)


          vm_list.each do |plc_vm|
            Rails.logger.info("[PLC vm #{plc_vm.vm_id}] checking")
            vm_instance = plc_client.vm_instance(plc_vm.vm_id)

            experiment = DataFarmingExperiment.find_by_id(plc_vm.experiment_id)

            if [:stopped, :terminated].include?(vm_instance.status)
              Rails.logger.info("[vm #{plc_vm.vm_id}] This VM is going to be removed from our db as it is terminated")
              SimulationManagerTempPassword.find_by_sm_uuid(plc_vm.sm_uuid).destroy
              plc_vm.destroy

            elsif ([:pending, :running].include?(vm_instance.status) and (plc_vm.created_at + plc_vm.time_limit.to_i.minutes < Time.now)) or experiment.nil? or (not experiment.is_running)
              Rails.logger.info("[vm #{plc_vm.vm_id}] This VM is going to be destroyed as it is done or should be done")
              vm_instance.terminate

            elsif (vm_instance.status == :running) and (not plc_vm.initialized)
              Rails.logger.info("[vm #{plc_vm.vm_id}] This VM is going to be initialized with SM now")
              initialize_sm_on(plc_vm, vm_instance)

            elsif (vm_instance.status == :pending) and (plc_vm.created_at + 10.minutes < Time.now)
              Rails.logger.info("[vm #{plc_vm.vm_id}] This VM will be restarted due to not being run for more then 10 minutes")
              vm_instance.reboot
            end

          end

        end
      rescue Exception => e
        Rails.logger.info("Exception #{e} in Amazon EC2 monitoring")
      end

      sleep(60)
    end
  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    plc_secrets = PLCloudSecrets.find_by_user_id(user.id)
    return 'error', 'You have to provide PLCloud secrets first!' if plc_secrets.nil?

    exp_image_id = PLCloudImage.find_by_id(additional_params['image_id']).image_id
    return 'error', 'You have to provide PLCloud Image information first!' if exp_image_id.nil?

    plc_client = PLCloudClient.new(plc_secrets)

    timestamp = Time.now.to_i

    sched_instances_ids = plc_client.create_instance("scalarm_#{timestamp}", exp_image_id, instances_count)

    sched_instances_ids.each do |instance_id|
      plc_vm = PLCloudVm.new({
                                 user_id: user.id,
                                 experiment_id: experiment_id,
                                 created_at: Time.now,
                                 time_limit: additional_params[:time_limit],
                                 vm_id: instance_id,
                                 sm_uuid: SecureRandom.uuid,
                                 initialized: false,
                                 start_at: additional_params['start_at']
                             })
      plc_vm.save
    end

    return 'ok', "You have scheduled #{sched_instances_ids.size} virtual machines on PLCloud!"

  end

  def default_additional_params
    {}
  end

  #def stop_simulation_managers(user, instances_count, experiment = nil)
  #  raise 'not implemented'
  #end

  def get_running_simulation_managers(user, experiment = nil)
    PLCloudVm.find_all_by_user_id(user.id).map do |instance|
      instance.to_s
    end
  end

  def add_credentials(user, params, session)
    self.send("handle_#{params[:credential_type]}_credentials", user, params, session)
  end

  def clean_tmp_credentials(user_id, session)
    if session.include?(:tmp_store_secrets_in_session) and (not user_id.nil?)
      PLCloudSecrets.find_all_by_user_id(user_id).each do |secrets|
        secrets.destroy
      end
    end

    if session.include?(:tmp_store_image_in_session) and (not user_id.nil?)
      PLCloudImage.find_all_by_user_id(user_id).each do |amazon_ami|
        amazon_ami.destroy if amazon_ami.experiment_id.to_s == session[:tmp_store_image_in_session].to_s
      end
    end

  end

  private

  def handle_secrets_credentials(user, params, session)
    credentials = PLCloudSecrets.find_by_user_id(user.id)

    if credentials.nil?
      credentials = PLCloudSecrets.new({'user_id' => user.id})
    end

    credentials.login = params[:login]
    credentials.password = params[:password]
    credentials.save

    if params.include?('store_secrets_in_session')
      session[:tmp_store_secrets_in_session] = true
    else
      session.delete(:tmp_store_secrets_in_session)
    end

    'ok'
  end

  def handle_image_credentials(user, params, session)
    credentials = PLCloudImage.find_all_by_user_id(user.id)

    if credentials.nil?
      credentials = PLCloudImage.new({'user_id' => user.id, 'experiment_id' => params[:experiment_id]})
    else
      credentials = credentials.select{|ami_creds| ami_creds.experiment_id == params[:experiment_id]}
      if credentials.blank?
        credentials = PLCloudImage.new({'user_id' => user.id, 'experiment_id' => params[:experiment_id]})
      else
        credentials = credentials.first
      end
    end

    credentials.image_id = params[:image_id]
    credentials.login = params[:image_login]
    credentials.password = params[:image_password]
    credentials.save

    if params.include?('store_template_in_session')
      session[:tmp_store_image_in_session] = params[:experiment_id]
    else
      session.delete(:tmp_store_image_in_session)
    end

    'ok'
  end

  def initialize_sm_on(vm_record, vm_instance)
    Rails.logger.debug('PLCloud SM initialization not implemented yet')
    return nil

    prepare_configuration_for_simulation_manager(vm_record.sm_uuid, vm_record.user_id, vm_record.experiment_id, vm_record.start_at)

    experiment_vm_image = PLCloudImage.find_by_image_id(vm_instance.image_id.to_s)

    error_counter = 0
    while true
      begin
        #  upload the code to the VM
        Net::SCP.start(vm_instance.public_dns_name, experiment_vm_image.login, password: experiment_vm_image.password) do |scp|
          scp.upload! "/tmp/scalarm_simulation_manager_#{vm_record.sm_uuid}.zip", '.'
        end

        Net::SSH.start(vm_instance.public_dns_name, experiment_vm_image.login, password: experiment_vm_image.password) do |ssh|
          ssh.exec!("source .rvm/environments/default; rm -rf scalarm_simulation_manager_#{vm_record.sm_uuid}; unzip scalarm_simulation_manager_#{vm_record.sm_uuid}.zip; cd scalarm_simulation_manager_#{vm_record.sm_uuid}; ruby simulation_manager.rb < /dev/null > /tmp/mylogfile 2>&1")
        end

        break
      rescue Exception => e
        Rails.logger.debug("Exception #{e} occured while communication with #{vm_instance.public_dns_name} --- #{error_counter}")
        error_counter += 1
        if error_counter > 10
          vm_instance.terminate
          break
        end
      end

      sleep(20)
    end

    vm_record.initialized = true
    vm_record.save
  end

end