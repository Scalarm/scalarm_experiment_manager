class ApplicationController < ActionController::Base
  USER, PASSWORD = 'eusas', 'change.ME'

  before_filter :check_authentication, :except => [:subscribe, :unsubscribe, :message, :login,
                                                   :get_experiment_id, :get_repository, :next_configuration,
                                                   :configuration, :set_configuration_done, :managers, :storage_managers, :code_base,
                                                   :next_simulation, :mark_as_complete
                                                   ]

  before_filter :vm_authentication, :only => [:get_experiment_id, :get_repository, :next_configuration,
                                              :configuration, :set_configuration_done, :managers, :storage_managers, :log_failure, :code_base,
                                              :next_simulation, :mark_as_complete]

  #before_filter :api_authentication, only: [ :start_experiment, :experiment_stats, :file_with_configurations ]


  
  # protect_from_forgery

  def current_user
    unless @scalarm_user.nil?
      @scalarm_user
    else
      nil
    end
  end
  
  protected

  def vm_authentication
    authenticate_or_request_with_http_basic do |user, password|
      user == USER && password == PASSWORD
    end
  end

  def check_authentication
    @scalarm_user = @current_user = nil
    Rails.logger.debug("DN: #{request.env['HTTP_SSL_CLIENT_S_DN']}")

    if session[:user]

      @current_user = User.find_by_id(session[:user])

    else

      if request.env.include?('HTTP_SSL_CLIENT_S_DN') and request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'
        Rails.logger.debug('We can use dn for authentication')
        @scalarm_user = ScalarmUser.find_by_dn(request.env['HTTP_SSL_CLIENT_S_DN'])

        if @scalarm_user.nil?

          Rails.logger.debug("Authentication failed: user with DN = #{request.env['HTTP_SSL_CLIENT_S_DN']} not found")

          flash[:error] = "Authentication failed: user with DN = #{request.env['HTTP_SSL_CLIENT_S_DN']} not found"
          redirect_to :login
        end

      else
        Rails.logger.debug('We should use user and pass for authentication')

        session[:intended_action] = action_name
        session[:intended_controller] = controller_name

        redirect_to :login
      end

    end

  end

  def api_authentication
    if session[:user]
      @current_user = User.find_by_id(session[:user])
    else
      authenticate_or_request_with_http_basic do |username, password|
        @current_user = User.authenticate(username, password)
        not @current_user.nil?
      end
    end
  end

end
