module PlGridOpenID
  require 'openid_providers/openid_utils'
  require 'gsi'

  require 'infrastructure_facades/pl_cloud_utils/pl_cloud_util'

  PLGRID_ENDPOINT_URI = 'https://openid.plgrid.pl/gateway'
  PLGRID_OID_URI = 'https://openid.plgrid.pl/gateway'

  # Invoke PL-Grid OpenID login procedure.
  # Optional parameters:
  # - generate_temp_pass - boolean - should temp password be generated
  def login_openid_plgrid
    begin
      oidreq = consumer.begin(PLGRID_OID_URI)
    rescue OpenID::OpenIDError => e
      flash[:error] = t('openid.provider_discovery_failed', provider_url: PLGRID_OID_URI,
                        error: e.to_s)
      redirect_to login_path
      return
    end

    # -- Attribute Exchange support --
    OpenIDUtils.request_ax_attributes(oidreq, [:proxy, :user_cert, :proxy_priv_key, :dn, :POSTresponse])

    return_to = openid_callback_plgrid_url((params[:generate_temp_pass] ? SecureRandom.hex(4) : nil))

    # remove following "/" from url (to match PL-Grid OpenID realm)
    realm = root_url.match(/(.*)\//)[1]

    if oidreq.send_redirect?(realm, return_to)
      redirect_to oidreq.redirect_url(realm, return_to)
    else
      render :text => oidreq.html_markup(realm, return_to, false, {'id' => 'openid_form'})
    end
  end

  # Action for callback from PL-Grid OpenID.
  # Optional parameters:
  # - temp_pass
  def openid_callback_plgrid
    validate_params(:openid_id, "openid.claimed_id", "openid.identity")

    # disabled for security reasons
    #Rails.logger.debug("PL-Grid OpenID callback with parameters: #{params}")

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

  def self.plgoid_dn_to_browser_dn(dn)
    '/' + dn.split(',').reverse.join('/')
  end

  def self.browser_dn_to_plgoid_dn(dn)
    dn.split('/').slice(1..-1).reverse.join(',')
  end

  private

  # Optional params:
  # - temp_pass - a password to set for created user
  def openid_callback_plgrid_success(oidresp, params)
    # check if response is from appropriate endpoint
    op_endpoint = params['openid.op_endpoint']
    if oidresp.endpoint.server_url != op_endpoint and op_endpoint != PLGRID_ENDPOINT_URI
      flash[:error] = t('openid.wrong_endpoint', endpoint: oidresp.endpoint.server_url)
      redirect_to login_path
    end

    # -- Attribute Exchange support --
    ax_attrs = OpenIDUtils::get_ax_attributes(oidresp, [:proxy, :user_cert, :proxy_priv_key, :dn])

    plgrid_identity = oidresp.identity_url
    plgrid_login = PlGridOpenID::strip_identity(oidresp.identity_url)

    Rails.logger.debug("User logged in with OpenID identity: #{plgrid_identity}")

    scalarm_user = PlGridOpenID::get_or_create_user(ax_attrs[:dn], plgrid_login, params[:temp_pass])

    x509_proxy_cert =
        Gsi::assemble_proxy_certificate(ax_attrs[:proxy], ax_attrs[:proxy_priv_key], ax_attrs[:user_cert])
    update_grid_credentials(scalarm_user.id, plgrid_login, x509_proxy_cert)

    pl_cloud_secret = PLCloudUtil::certs_to_pl_cloud_secret_proxy(ax_attrs[:proxy], ax_attrs[:user_cert])
    update_pl_cloud_credentials(scalarm_user.id, plgrid_login, pl_cloud_secret)

    flash[:notice] = t('openid.verification_success', identity: oidresp.display_identifier)
    session[:user] = scalarm_user.id.to_s
    successful_login
  end

  def self.get_or_create_user(dn, plgrid_login, password=nil)
    OpenIDUtils::get_user_with(dn: dn, login: plgrid_login) or
        OpenIDUtils::get_user_with(dn: dn) or OpenIDUtils::get_user_with(login: plgrid_login) or
        OpenIDUtils::create_user_with(plgrid_login, password, dn: dn, login: plgrid_login)
  end

  def update_grid_credentials(scalarm_user_id, plgrid_login, proxy_cert)
    user_id = BSON::ObjectId(scalarm_user_id.to_s)
    grid_credentials =
        (GridCredentials.find_by_user_id(user_id) or GridCredentials.new(user_id: user_id))
    grid_credentials.login = plgrid_login
    grid_credentials.secret_proxy = proxy_cert
    grid_credentials.save
  end

  def update_pl_cloud_credentials(scalarm_user_id, plgrid_login, proxy_secret)
    pl_cloud_credentials = (CloudSecrets.find_by_query(user_id: scalarm_user_id.to_s, cloud_name: 'pl_cloud') or
        CloudSecrets.new(user_id: scalarm_user_id, cloud_name: 'pl_cloud'))
    pl_cloud_credentials.login = plgrid_login
    pl_cloud_credentials.secret_proxy = proxy_secret
    pl_cloud_credentials.save
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

  def self.strip_identity(identity_uri)
    m = identity_uri.match(/\Ahttps:\/\/openid\.plgrid\.pl\/(\w+)\z/)
    m ? m[1] : nil
  end
end