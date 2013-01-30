class UserControllerController < ApplicationController

  def login
    if request.post?
      begin
        session[:user] = User.authenticate(params[:username], params[:password]).id
        session[:grid_credentials] = User.find(session[:user]).grid_credentials

        flash[:notice] = "You have log in successfully"

        #redirect_to :controller => session[:intended_controller], :action => session[:intended_action]
        redirect_to :controller => "experiments", :action => "latest_running_experiment"
      rescue Exception => e
        flash[:error] = e.to_s

        redirect_to :controller => "user_controller", :action => "login"
      end
    end
  end

  def logout
    flash[:notice] = "You have log out successfully"
    session[:user] = nil
    session[:grid_credentials] = nil

    if session[:aws_access_key]
      session[:aws_access_key] = nil
      session[:aws_secret] = nil

      if session[:aws_private_key]
        private_key_path = File.join(Rails.root, "tmp", session[:aws_private_key])
        File.delete(private_key_path) if File.exist?(private_key_path)
      end

      session[:aws_private_key] = nil
    end

    redirect_to :action => "login"
  end

  def account
    @current_user = User.find(session[:user])
  end

  def change_password
    @current_user = User.find(session[:user])

    if params[:password] != params[:password_repeat]
      flash[:error] = "'Password' and 'Repeat password' must be equal!"
    else
      @current_user.password = params[:password]
      @current_user.save

      flash[:notice] = "You have changed your password."
    end

    redirect_to :action => "account"
  end

end
