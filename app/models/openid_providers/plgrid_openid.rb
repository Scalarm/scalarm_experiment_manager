module PlGridOpenID
  require 'openid_providers/openid_utils'

  # Invoke PL-Grid OpenID login procedure.
  def login_openid_plgrid
    plgrid_oid_url = 'https://openid.plgrid.pl/gateway'

    begin
      oidreq = consumer.begin(plgrid_oid_url)
    rescue OpenID::OpenIDError => e
      flash[:error] = t('openid.provider_discovery_failed', provider_url: plgrid_oid_url,
                        error: e.to_s)
      redirect_to login_path
      return
    end

    # -- Attribute Exchange support --
    axreq =  OpenID::AX::FetchRequest.new

    [:proxy, :user_cert, :proxy_priv_key].each do |attr_name|
      attr = OpenID::AX::AttrInfo.new(OpenIDUtils::AX_URI[attr_name], attr_name.to_s, true)
      attr.required = true
      axreq.add(attr)
    end

    oidreq.add_extension(axreq)

    return_to = openid_callback_plgrid_url

    # remove following "/" from url (to match PL-Grid OpenID realm)
    realm = root_url.match(/(.*)\//)[1]

    if oidreq.send_redirect?(realm, return_to)
      redirect_to oidreq.redirect_url(realm, return_to)
    else
      render :text => oidreq.html_markup(realm, return_to, false, {'id' => 'openid_form'})
    end
  end

  # Action for callback from PL-Grid OpenID.
  def openid_callback_plgrid
    Rails.logger.debug("PL-Grid OpenID callback with parameters: #{params}")

    parameters = params.reject{|k,v|request.path_parameters[k]}
    parameters.reject!{|k,v|%w{action controller}.include? k.to_s}
    oidresp = consumer.complete(parameters, openid_callback_plgrid_url)

    if %w{success failure cancel}.include? oidresp.status.to_s
      self.send("openid_callback_plgrid_#{oidresp.status.to_s}", oidresp, params)
    else
      flash[:error] = t('openid.unknown_status', status: oidresp.status)
      redirect_to login_path
    end

  end

  private

  def openid_callback_plgrid_success(oidresp, params)
  # check if response is from appropriate endpoint
    op_endpoint = params['openid.op_endpoint']
    if oidresp.endpoint.server_url != op_endpoint and op_endpoint != plgrid_endpoint_url
      flash[:error] = t('openid.wrong_endpoint', endpoint: oidresp.endpoint.server_url)
      redirect_to login_path
    end

    # -- Attribute Exchange support --
    ax_resp = OpenID::AX::FetchResponse.from_success_response(oidresp)

    # manually add alias to response
    [:proxy, :user_cert, :proxy_priv_key].each do |attr_name|
      ax_resp.aliases.add_alias(OpenIDUtils::AX_URI[attr_name], attr_name.to_s)
    end

    resp_proxy = ax_resp.get_extension_args['value.proxy']
    resp_user_cert = ax_resp.get_extension_args['value.user_cert']
    resp_proxy_priv_key = ax_resp.get_extension_args['value.proxy_priv_key']

    render text: "Proxy:\n#{resp_proxy.to_s}\nUser cert:\n#{resp_user_cert.to_s}\nProxy priv key:\n#{resp_proxy_priv_key}" #.gsub('<br>', "\n")
  end

  def openid_callback_plgrid_failure(oidresp, params)
    if oidresp.display_identifier
      flash[:error] = t('openid.verification_failed_identity', identity: oidresp.display_identifier,
                        message: oidresp.message)
    else
      flash[:error] = t('openid.verification_failed', message: oidresp.message)
    end
    redirect_to login_path
  end

  def openid_callback_plgrid_cancel(oidresp, params)
    flash[:error] = t('openid.cancelled')
    redirect_to login_path
  end
end