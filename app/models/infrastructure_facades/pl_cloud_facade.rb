require 'securerandom'

require_relative 'pl_cloud_credentials/pl_cloud_secrets'
require_relative 'pl_cloud_credentials/pl_cloud_image'

class PLCloudFacade < InfrastructureFacade

  def current_state(user)
    # TODO
    "TODO"
  end

  def start_monitoring
    # TODO
    while true do
      Rails.logger.info("[plcloud] #{Time.now} - monitoring thread is working TODO")
      sleep(60)
    end
  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})
    # TODO
    return 'error', "Starting simulation manager for PLCloud is not implemented yet."
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

    if session.include?(:tmp_store_ami_in_session) and (not user_id.nil?)
      PLCloudImage.find_all_by_user_id(user_id).each do |amazon_ami|
        amazon_ami.destroy if amazon_ami.experiment_id.to_s == session[:tmp_store_ami_in_session].to_s
      end
    end

  end

  private

  def handle_secrets_credentials(user, params, session)
    credentials = PLCloudSecrets.find_by_user_id(user.id)

    if credentials.nil?
      credentials = PLCloudSecrets.new({'user_id' => user.id})
    end

    # TODO: change parametes send from form to login/password
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

    # TODO: change correspoding params in form
    credentials.image_id = params[:image_id]
    credentials.login = params[:image_login] # TODO: ??
    credentials.password = params[:image_password] # TODO: ??
    credentials.save

    if params.include?('store_template_in_session')
      session[:tmp_store_image_in_session] = params[:experiment_id]
    else
      session.delete(:tmp_store_image_in_session)
    end

    'ok'
  end

  #def initialize_sm_on(vm_record, vm_instance)
  #  prepare_configuration_for_simulation_manager(vm_record.sm_uuid, vm_record.user_id, vm_record.experiment_id, vm_record.start_at)
  #
  #  # user_amis, experiment_ami = AmazonAmi.find_all_by_user_id(vm_record.user_id), nil
  #  # user_amis.each do |ami|
  #  #   if ami.experiment_id == vm_record.experiment_id
  #  #     experiment_ami = ami
  #  #     break
  #  #   end
  #  # end
  #
  #  experiment_vm_template = PLCloudImage.find_by_template_id(vm_instance.image_id.to_s)
  #
  #  error_counter = 0
  #  while true
  #    begin
  #      #  upload the code to the VM
  #      Net::SCP.start(vm_instance.public_dns_name, experiment_vm_template.login, password: experiment_vm_template.password) do |scp|
  #        scp.upload! "/tmp/scalarm_simulation_manager_#{vm_record.sm_uuid}.zip", '.'
  #      end
  #
  #      Net::SSH.start(vm_instance.public_dns_name, experiment_vm_template.login, password: experiment_vm_template.password) do |ssh|
  #        ssh.exec!("source .rvm/environments/default; rm -rf scalarm_simulation_manager_#{vm_record.sm_uuid}; unzip scalarm_simulation_manager_#{vm_record.sm_uuid}.zip; cd scalarm_simulation_manager_#{vm_record.sm_uuid}; ruby simulation_manager.rb < /dev/null > /tmp/mylogfile 2>&1")
  #      end
  #
  #      break
  #    rescue Exception => e
  #      Rails.logger.debug("Exception #{e} occured while communication with #{vm_instance.public_dns_name} --- #{error_counter}")
  #      error_counter += 1
  #      if error_counter > 10
  #        vm_instance.terminate
  #        break
  #      end
  #    end
  #
  #    sleep(20)
  #  end
  #
  #  vm_record.initialized = true
  #  vm_record.save
  #end

end