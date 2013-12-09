require 'openid'
require 'openid/extensions/ax'

class UserControllerController < ApplicationController
  include UserControllerHelper

  def successful_login_path
    experiments_path
  end

  def login
    Rails.logger.debug("Flash #{flash[:error]}")
    if request.post?
      begin
        session[:user] = ScalarmUser.authenticate_with_password(params[:username], params[:password]).id
        #session[:grid_credentials] = GridCredentials.find_by_user_id(session[:user])

        flash[:notice] = t('login_success')

        redirect_to successful_login_path
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

  # --- OpenID support ---

  @@openid_ax_email_url = 'http://schema.openid.net/contact/email'
  @@openid_ax_email_alias = 'email'

  # Invoke Google OpenID login procedure.
  def login_openid_google
    google_oid_url = 'https://www.google.com/accounts/o8/id'

    begin
      oidreq = consumer.begin(google_oid_url)
    rescue OpenID::OpenIDError => e
      flash[:error] = t('openid.provider_discovery_failed', provider_url: google_oid_url,
                         error: e.to_s)
      redirect_to login_path
      return
    end

    # -- Attribute Exchange support --
    axreq =  OpenID::AX::FetchRequest.new
    attr_email = OpenID::AX::AttrInfo.new(@@openid_ax_email_url, @@openid_ax_email_alias, true)
    attr_email.required = true
    axreq.add(attr_email)
    oidreq.add_extension(axreq)

    return_to = openid_callback_google_url
    realm = login_url

    if oidreq.send_redirect?(realm, return_to)
      redirect_to oidreq.redirect_url(realm, return_to)
    else
      render :text => oidreq.html_markup(realm, return_to, false, {'id' => 'openid_form'})
    end
  end

  # Action for callback from Google OpenID.
  def openid_callback_google
    restrict_email = 'jakub.liput@gmail.com'
    google_endpoint_url = 'https://www.google.com/accounts/o8/ud'

    Rails.logger.debug("Google OpenID callback with parameters: #{params}")

    parameters = params.reject{|k,v|request.path_parameters[k]}
    parameters.reject!{|k,v|%w{action controller}.include? k.to_s}
    oidresp = consumer.complete(parameters, openid_callback_google_url)

    # Got OID response, check status
    case oidresp.status

      when OpenID::Consumer::SUCCESS

        # check if response is from appropriate endpoint
        op_endpoint = params['openid.op_endpoint']
        if oidresp.endpoint.server_url != op_endpoint and op_endpoint != google_endpoint_url
          flash[:error] = t('openid.wrong_endpoint', endpoint: oidresp.endpoint.server_url)
          redirect_to login_path
        end

        # -- Attribute Exchange support --
        ax_resp = OpenID::AX::FetchResponse.from_success_response(oidresp)

        # manually add alias to response
        ax_resp.aliases.add_alias(@@openid_ax_email_url, @@openid_ax_email_alias)

        resp_email = ax_resp.get_extension_args['value.email']

        if resp_email
          resp_identity = params['openid.identity']
          Rails.logger.debug("User logged in with OpenID identity: #{resp_identity}")

          # FIXME: Remove temporary restriction for one user from openid
          if resp_email == restrict_email

            # TODO: method name?
            user = ScalarmUser.find_by('openid_google_email', resp_email)

            if user
              flash[:notice] = t('openid.verification_success', identity: oidresp.display_identifier)
              session[:user] = user._id
              redirect_to successful_login_path
            else
              flash[:error] = t('openid.google.no_openid_user', email: resp_email)
              redirect_to login_path
            end

          else # only for test-users

            flash[:error] = t('openid.google.tmp_restrict')
            redirect_to login_path

          end

        else
          flash[:error] = t('openid.google.no_email_provided')
          Rails.logger.error("Error authenticating with OpenID: no email provided by OpenID Server. Response: #{params}")
          redirect_to login_path
        end

      when OpenID::Consumer::FAILURE
        if oidresp.display_identifier
          flash[:error] = t('openid.verification_failed_identity', identity: oidresp.display_identifier,
                            message: oidresp.message)
        else
          flash[:error] = t('openid.verification_failed', message: oidresp.message)
        end
        redirect_to login_path

      when OpenID::Consumer::CANCEL
        flash[:error] = t('openid.cancelled')
        redirect_to login_path

      ## Please uncomment below state handler when using OpenID immediate mode
      ## and OpenID direct user url
      #when OpenID::Consumer::SETUP_NEEDED
      #  msg = "OpenID immediate request failed - Setup Needed"
      #  flash[:alert] = msg

      else
        flash[:error] = t('openid.unknown_status', status: oidresp.status)
        redirect_to login_path

    end
  end

  private

  # Get stateless mode OpenID::Consumer instance for this controller.
  def consumer
    if @consumer.nil?
      @consumer = OpenID::Consumer.new(session, nil) # 'nil' for stateless mode
    end
    return @consumer
  end

end
