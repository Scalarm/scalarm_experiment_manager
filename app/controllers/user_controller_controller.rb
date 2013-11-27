class UserControllerController < ApplicationController
  def login
    if request.post?
      begin
        session[:user] = ScalarmUser.authenticate_with_password(params[:username], params[:password]).id
        #session[:grid_credentials] = GridCredentials.find_by_user_id(session[:user])

        flash[:notice] = t('login_success')

        redirect_to experiments_path
      rescue Exception => e
        Rails.logger.debug("Exception: #{e}")
        reset_session
        flash[:error] = e.to_s

        redirect_to login_path
      end
    end
  end

  def logout
    InfrastructureFacade.get_registered_infrastructures.each do |infrastructure_id, infrastructure_info|
      infrastructure_info[:facade].clean_tmp_credentials(@current_user.id, session)
    end

    reset_session
    flash[:notice] = t('logout_success')

    redirect_to login_path
  end

  def change_password
    if params[:password] != params[:password_repeat]
      flash[:error] = t('password_repeat_error')
    else
      @current_user.password = params[:password]
      @current_user.save

      flash[:notice] = t('password_changed')
    end

    redirect_to :action => 'account'
  end
end
