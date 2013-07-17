require_relative 'amazon_credentials/amazon_ami'
require_relative 'amazon_credentials/amazon_secrets'

class AmazonFacade < InfrastructureFacade

  def current_state(user)
    'No information available'
  end

  def start_monitoring

  end

  def start_simulation_managers(user, instances_count, experiment_id, additional_params = {})

  end

  def default_additional_params
    {}
  end

  #def stop_simulation_managers(user, instances_count, experiment = nil)
  #  raise 'not implemented'
  #end

  def get_running_simulation_managers(user, experiment = nil)
    []
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
        amazon_ami.destroy if amazon_ami.experiment_id == session[:tmp_store_ami_in_session]
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

end