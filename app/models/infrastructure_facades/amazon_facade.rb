require 'aws-sdk'
require 'securerandom'

require_relative 'amazon_credentials/amazon_ami'
require_relative 'amazon_credentials/amazon_secrets'

class AmazonFacade < InfrastructureFacade

  def current_state(user)
    ec2 = get_ec2_for(user)

    return 'No information available' if ec2.nil?

    ec2_running_instances = ec2.instances.select{|instance| instance.status != 'terminated' }

    "You have #{ec2_running_instances.size} virtual machines running"
  end

  def start_monitoring
    while true do
      begin
        Rails.logger.debug("#{Time.now} - Amazon EC2 monitoring thread is working")
        amazon_vms = AmazonVm.all.group_by(&:user_id)

        amazon_vms.each do |user_id, vm_list|
          user = ScalarmUser.find_by_id(user_id)
          ec2 = get_ec2_for(user)

          if ec2.nil?
            Rails.logger.debug("We cannot monitor VMs for #{user.login} due secrets lacking")
            next
          end

          vm_list.each do |amazon_vm|
            Rails.logger.debug("[vm #{amazon_vm.vm_id}] checking")
            vm_instance = ec2.instances[amazon_vm.vm_id]
            experiment = DataFarmingExperiment.find_by_id(amazon_vm.experiment_id)

            if [:stopped, :terminated].include?(vm_instance.status)
              Rails.logger.debug("[vm #{amazon_vm.vm_id}] This VM is going to be removed from our db as it is terminated")
              SimulationManagerTempPassword.find_by_sm_uuid(amazon_vm.sm_uuid).destroy
              amazon_vm.destroy

            elsif ([:pending, :running].include?(vm_instance.status) and (amazon_vm.created_at + amazon_vm.time_limit.to_i.minutes < Time.now)) or experiment.nil? or (not experiment.is_running)
              Rails.logger.debug("[vm #{amazon_vm.vm_id}] This VM is going to be destroyed as it is done or should be done")
              vm_instance.terminate

            elsif (vm_instance.status == :running) and (not amazon_vm.initialized)
              Rails.logger.debug("[vm #{amazon_vm.vm_id}] This VM is going to be initialized with SM now")
              initialize_sm_on(amazon_vm, vm_instance)

            elsif (vm_instance.status == :pending) and (amazon_vm.created_at + 10.minutes < Time.now)
              Rails.logger.debug("[vm #{amazon_vm.vm_id}] This VM will be restarted due to not being run for more then 10 minutes")
              vm_instance.reboot
            end

          end

        end
      rescue Exception => e
        Rails.logger.debug("Exception #{e} in Amazon EC2 monitoring")
      end

      sleep(60)
    end
  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    ec2 = get_ec2_for(user)
    return 'error', 'You have to provide Amazon secrets first!' if ec2.nil?

    user_amis, experiment_ami = AmazonAmi.find_all_by_user_id(user.id), nil
    user_amis.each do |ami|
      if ami.experiment_id == experiment_id
        experiment_ami = ami
        break
      end
    end

    return 'error', 'You have to provide Amazon AMI information first!' if experiment_ami.nil?

    ec2_region = ec2.regions['us-east-1']
    scheduled_instances = ec2_region.instances.create(:image_id => experiment_ami.ami_id,
                                :count => instances_count,
                                :instance_type => additional_params[:instance_type],
                                :security_groups => [ additional_params[:security_group] ])

    scheduled_instances = [ scheduled_instances ] unless scheduled_instances.respond_to?(:each)

    scheduled_instances.each do |instance|
      amazon_vm = AmazonVm.new({
          user_id: user.id,
          experiment_id: experiment_id,
          created_at: Time.now,
          time_limit: additional_params[:time_limit],
          vm_id: instance.instance_id,
          instance_type: instance.instance_type,
          sm_uuid: SecureRandom.uuid,
          initialized: false
                         })
      amazon_vm.save
    end

    return 'ok', "You have scheduled #{scheduled_instances.size} virtual machines on Amazon EC2!"
  end

  def default_additional_params
    {}
  end

  #def stop_simulation_managers(user, instances_count, experiment = nil)
  #  raise 'not implemented'
  #end

  def get_running_simulation_managers(user, experiment = nil)
    AmazonVm.find_all_by_user_id(user.id).map do |instance|
      instance.to_s
    end
  end

  def add_credentials(user, params, session)
    self.send("handle_#{params[:credential_type]}_credentials", user, params, session)
  end

  def clean_tmp_credentials(user_id, session)
    if session.include?(:tmp_store_secrets_in_session)
      AmazonSecrets.find_by_user_id(user_id).destroy
    end

    if session.include?(:tmp_store_ami_in_session)
      AmazonAmi.find_all_by_user_id(user_id).each do |amazon_ami|
        amazon_ami.destroy if amazon_ami.experiment_id.to_s == session[:tmp_store_ami_in_session].to_s
      end
    end

  end

  private

  def handle_secrets_credentials(user, params, session)
    credentials = AmazonSecrets.find_by_user_id(user.id)

    if credentials.nil?
      credentials = AmazonSecrets.new({'user_id' => user.id})
    end

    credentials.access_key = params[:access_key]
    credentials.secret_key = params[:secret_access_key]
    credentials.save

    if params.include?('store_secrets_in_session')
      session[:tmp_store_secrets_in_session] = true
    else
      session.delete(:tmp_store_secrets_in_session)
    end

    'ok'
  end

  def handle_ami_credentials(user, params, session)
    credentials = AmazonAmi.find_all_by_user_id(user.id)

    if credentials.nil?
      credentials = AmazonAmi.new({'user_id' => user.id, 'experiment_id' => params[:experiment_id]})
    else
      credentials = credentials.select{|ami_creds| ami_creds.experiment_id == params[:experiment_id]}
      if credentials.blank?
        credentials = AmazonAmi.new({'user_id' => user.id, 'experiment_id' => params[:experiment_id]})
      else
        credentials = credentials.first
      end
    end

    credentials.ami_id = params[:ami_id]
    credentials.login = params[:ami_login]
    credentials.password = params[:ami_password]
    credentials.save

    if params.include?('store_ami_in_session')
      session[:tmp_store_ami_in_session] = params[:experiment_id]
    else
      session.delete(:tmp_store_ami_in_session)
    end

    'ok'
  end

  def get_ec2_for(user)
    secrets = AmazonSecrets.find_by_user_id(user.id)

    return nil if secrets.nil?

    AWS::EC2.new(access_key_id: secrets.access_key, secret_access_key: secrets.secret_key)
  end

  def initialize_sm_on(vm_record, vm_instance)
    prepare_configuration_for_simulation_manager(vm_record.sm_uuid, vm_record.user_id, vm_record.experiment_id)

    user_amis, experiment_ami = AmazonAmi.find_all_by_user_id(vm_record.user_id), nil
    user_amis.each do |ami|
      if ami.experiment_id == vm_record.experiment_id
        experiment_ami = ami
        break
      end
    end

    error_counter = 0
    while true
      begin
        #  upload the code to the VM
        Net::SCP.start(vm_instance.public_dns_name, experiment_ami.login, password: experiment_ami.password) do |scp|
          scp.upload! "/tmp/scalarm_simulation_manager_#{vm_record.sm_uuid}.zip", '.'
        end

        Net::SSH.start(vm_instance.public_dns_name, experiment_ami.login, password: experiment_ami.password) do |ssh|
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