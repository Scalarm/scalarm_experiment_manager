require 'google/api_client'

module GoogleOpenID
  require 'openid_providers/openid_utils'

  GOOGLE_OID_URI = 'https://www.google.com/accounts/o8/id'
  GOOGLE_ENDPOINT_URI = 'https://www.google.com/accounts/o8/ud'

  def login_oauth_google
    client_secrets = Google::APIClient::ClientSecrets.load((Rails.root + 'config' + 'google_client_secrets.json').to_s)

    auth_client = client_secrets.to_authorization
    auth_client.update!(scope: 'email')
    
    Rails.logger.debug("Authorization URI: #{auth_client.authorization_uri.to_s}")

    redirect_to auth_client.authorization_uri.to_s
  end

  # Invoke Google OpenID login procedure.
  def login_openid_google
    begin
      oidreq = consumer.begin(GOOGLE_OID_URI)
    rescue OpenID::OpenIDError => e
      flash[:error] = t('openid.provider_discovery_failed', provider_url: google_oid_url,
                        error: e.to_s)
      redirect_to login_path
      return
    end

    # -- Attribute Exchange support --
    OpenIDUtils.request_ax_attributes(oidreq, [:email])

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
    validate(
        "openid.claimed_id".to_sym => :security_openid_id,
        "openid.identity".to_sym => :security_openid_id
    )
    Rails.logger.debug("Google OpenID callback with parameters: #{params}")

    parameters = params.reject{|k,v|request.path_parameters[k]}
    parameters.reject!{|k,v|%w{action controller}.include? k.to_s}
    oidresp = consumer.complete(parameters, openid_callback_google_url)

    if %w{success failure cancel}.include? oidresp.status.to_s
      self.send("openid_callback_google_#{oidresp.status.to_s}", oidresp, params)
    else
      flash[:error] = t('openid.unknown_status', status: oidresp.status)
      redirect_to login_path
    end

  end

  def oauth2_google_callback
    if params.include? 'code'
      client_secrets = Google::APIClient::ClientSecrets.load (Rails.root + 'config' + 'google_client_secrets.json').to_s

      auth_client = client_secrets.to_authorization

      auth_client.code = params['code']
      auth_client.fetch_access_token!
      auth_client.client_secret = nil

      begin
        api_client = Google::APIClient.new
        api_client.authorization = auth_client
        oauth2 = api_client.discovered_api('oauth2', 'v2')
        result = api_client.execute!(:api_method => oauth2.userinfo.get)

        if result.status == 200
          user_info = result.data

          if user_info != nil && user_info.id != nil
            user = OpenIDUtils::get_or_create_user_with(:email, user_info["email"])

            flash[:notice] = t('openid.verification_success', identity: user_info["email"])
            session[:user] = user.id.to_s
            session[:uuid] = SecureRandom.uuid

            successful_login
          else

            Rails.logger.debug(t 'oauth.no_email_provided')
            flash[:error] = t 'oauth.no_email_provided'
          end
        else
          Rails.logger.debug(t('oauth.error_occured', error: result.data['error']['message']))
          flash[:error] = t('oauth.error_occured', error: result.data['error']['message'])
        end
      rescue Exception => e
        Rails.logger.error(t('oauth.error_occured', error: e.message))
        flash[:error] = t('oauth.error_occured', error: e.message)
      end

    elsif params.include? 'error'
      Rails.logger.debug(t('oauth.error_occured', error: params["error"]))
      flash[:error] = t('oauth.error_occured', error: params["error"])
    else
      Rails.logger.debug(t('oauth.no_code_or_error_set'))
      flash[:error] = t('oauth.no_code_or_error_set')
    end

    redirect_to login_path if not session.include? :user
  end

  private

  def openid_callback_google_success(oidresp, params)
# check if response is from appropriate endpoint
    op_endpoint = params['openid.op_endpoint']
    if oidresp.endpoint.server_url != op_endpoint and op_endpoint != GOOGLE_ENDPOINT_URI
      flash[:error] = t('openid.wrong_endpoint', endpoint: oidresp.endpoint.server_url)
      redirect_to login_path
    end

    # -- Attribute Exchange support --
    ax_attrs = OpenIDUtils.get_ax_attributes(oidresp, [:email])
    resp_email = ax_attrs[:email]

    if resp_email
      resp_identity = params['openid.identity']
      Rails.logger.debug("User logged in with OpenID identity: #{resp_identity}")

      # create new user if there is no such
      user = OpenIDUtils::get_or_create_user_with(:email, resp_email)

      flash[:notice] = t('openid.verification_success', identity: oidresp.display_identifier)
      session[:user] = user.id.to_s
      session[:uuid] = SecureRandom.uuid
      successful_login

    else
      flash[:error] = t('openid.google.no_email_provided')
      Rails.logger.error("Error authenticating with OpenID: no email provided by OpenID Server. Response: #{params}")
      redirect_to login_path
    end
  end

  def openid_callback_google_failure(oidresp, params)
    if oidresp.display_identifier
      flash[:error] = t('openid.verification_failed_identity', identity: oidresp.display_identifier,
                        message: oidresp.message)
    else
      flash[:error] = t('openid.verification_failed', message: oidresp.message)
    end
    redirect_to login_path
  end

  def openid_callback_google_cancel(oidresp, params)
    flash[:error] = t('openid.cancelled')
    redirect_to login_path
  end
end