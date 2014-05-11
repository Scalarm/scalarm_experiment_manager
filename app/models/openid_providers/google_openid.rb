module GoogleOpenID
  require 'openid_providers/openid_utils'

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
    attr_email = OpenID::AX::AttrInfo.new(OpenIDUtils::AX_EMAIL_URI, OpenIDUtils::AX_EMAIL_ALIAS, true)
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
    google_endpoint_url = 'https://www.google.com/accounts/o8/ud'

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

  private

  def openid_callback_google_success(oidresp, params)
# check if response is from appropriate endpoint
    op_endpoint = params['openid.op_endpoint']
    if oidresp.endpoint.server_url != op_endpoint and op_endpoint != google_endpoint_url
      flash[:error] = t('openid.wrong_endpoint', endpoint: oidresp.endpoint.server_url)
      redirect_to login_path
    end

    # -- Attribute Exchange support --
    ax_resp = OpenID::AX::FetchResponse.from_success_response(oidresp)

    # manually add alias to response
    ax_resp.aliases.add_alias(OpenIDUtils::AX_EMAIL_URI, OpenIDUtils::AX_EMAIL_ALIAS)

    resp_email = ax_resp.get_extension_args['value.email']

    if resp_email
      resp_identity = params['openid.identity']
      Rails.logger.debug("User logged in with OpenID identity: #{resp_identity}")

      user = ScalarmUser.find_by('email', resp_email)

      # create new user if there is no such
      unless user
        user = ScalarmUser.new({ email: resp_email })
        user.save
      end

      flash[:notice] = t('openid.verification_success', identity: oidresp.display_identifier)
      session[:user] = user.id
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