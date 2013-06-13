class UserControllerController < ApplicationController

  def login
    if request.post?
      begin
        session[:user] = User.authenticate(params[:username], params[:password]).id
        session[:grid_credentials] = GridCredentials.find_by_user_id(session[:user])

        flash[:notice] = t('login_success')

        redirect_to experiments_latest_running_experiment_path
      rescue Exception => e
        flash[:error] = e.to_s
        session[:user] = nil

        redirect_to login_path
      end
    else
      render layout: 'foundation_application'
    end


  end

  def logout
    flash[:notice] = t('logout_success')

    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
      infrastructure_info[:facade].clean_tmp_credentials(session[:user], session)
    end

    session[:user] = nil
    session[:grid_credentials] = nil

    if session[:aws_access_key]
      session[:aws_access_key] = nil
      session[:aws_secret] = nil

      if session[:aws_private_key]
        private_key_path = File.join(Rails.root, 'tmp', session[:aws_private_key])
        File.delete(private_key_path) if File.exist?(private_key_path)
      end

      session[:aws_private_key] = nil
    end

    redirect_to login_path
  end

  def account
    @current_user = User.find(session[:user])

    render layout: 'foundation_application'
  end

  def change_password
    @current_user = User.find(session[:user])

    if params[:password] != params[:password_repeat]
      flash[:error] = t('password_repeat_error')
    else
      @current_user.password = params[:password]
      @current_user.save

      flash[:notice] = t('password_changed')
    end

    redirect_to :action => "account"
  end

end
