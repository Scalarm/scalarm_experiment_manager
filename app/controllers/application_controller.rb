class ApplicationController < ActionController::Base
  USER, PASSWORD = 'eusas', 'change.ME'

  before_filter :check_authentication, :except => [:subscribe, :unsubscribe, :message, :login,
                                                   :get_experiment_id, :get_repository, :next_configuration,
                                                   :configuration, :set_configuration_done, :managers, :storage_managers, :code_base,
                                                   :next_simulation, :mark_as_complete, :histogram, :start_experiment]

  before_filter :vm_authentication, :only => [:get_experiment_id, :get_repository, :next_configuration,
                                              :configuration, :set_configuration_done, :managers, :storage_managers, :log_failure, :code_base,
                                              :next_simulation, :mark_as_complete, :histogram]


  
  # protect_from_forgery
  
  protected

  def vm_authentication
    authenticate_or_request_with_http_basic do |user, password|
      user == USER && password == PASSWORD
    end
  end

  def check_authentication
    unless session[:user]
      session[:intended_action] = action_name
      session[:intended_controller] = controller_name

      redirect_to :action => :login, :controller => :user_controller
    end
  end

  def api_authentication
    unless session[:user]
      authenticate_or_request_with_http_basic do |username, password|
        not User.authenticate(username, password).nil?
      end
    end
  end

end
