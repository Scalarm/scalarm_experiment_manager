# each authentication method must set:
# - session[:user] to user id as string,
# - @current_user or @sm_user to scalarm user or simulation manager temp pass respectively
# - @session_auth to true if this is session-based authentication
require 'grid-proxy'

module ScalarmAuthentication

  PROXY_HEADER = 'X-Proxy-Cert'

  RAILS_PROXY_HEADER = 'HTTP_' + PROXY_HEADER.upcase.gsub('-', '_')

  def initialize
    super
    @proxy_s = nil
  end

  # the main authentication function + session management
  def authenticate
    Rails.logger.debug("[authentication] starting")
    @current_user = nil; @sm_user = nil; @session_auth = false; @user_session = nil

    case true
      when (not session[:user].blank?)
        authenticate_with_session

      when (use_proxy_auth? and proxy_provided?)
        authenticate_with_proxy

      when password_provided?
        authenticate_with_password

      when certificate_provided?
        authenticate_with_certificate
    end

    if @current_user.nil? and @sm_user.nil?
      authentication_failed
    elsif @sm_user.nil?
      @user_session = UserSession.create_and_update_session(session[:user], session[:uuid])
    end
  end

  def authenticate_with_session
    Rails.logger.debug("[authentication] using session: user: #{session[:user]}, uuid: #{session[:uuid]}")
    session_id = BSON::ObjectId(session[:user].to_s)

    @user_session = UserSession.where(session_id: session_id, uuid: session[:uuid]).first

    if (not @user_session.nil?) and @user_session.valid?
      Rails.logger.debug("[authentication] scalarm user session exists and its valid")
      @current_user = ScalarmUser.find_by_id(session_id)
      @session_auth = true unless @current_user.blank?
    else
      flash[:error] = t('session.expired')
      Rails.logger.debug("[authentication] scalarm user session doesnt exist or its invalid")
    end
  end

  def certificate_provided?
    request.env.include?('HTTP_SSL_CLIENT_S_DN') and
        request.env['HTTP_SSL_CLIENT_S_DN'] != '(null)' and
        request.env['HTTP_SSL_CLIENT_VERIFY'] == 'SUCCESS'
  end

  def authenticate_with_certificate
    cert_dn = request.env['HTTP_SSL_CLIENT_S_DN']
    Rails.logger.debug("[authentication] using DN: '#{cert_dn}'")

    begin
      session[:user] = ScalarmUser.authenticate_with_certificate(cert_dn).id.to_s
      session[:uuid] = SecureRandom.uuid
      @current_user = ScalarmUser.find_by_id(session[:user].to_s)
    rescue Exception => e
      @current_user = nil
      flash[:error] = e.to_s
    end
  end

  def password_provided?
    request.env.include?('HTTP_AUTHORIZATION') and request.env['HTTP_AUTHORIZATION'].include?('Basic')
  end

  def authenticate_with_password
    authenticate_or_request_with_http_basic do |login, password|
      temp_pass = SimulationManagerTempPassword.find_by_sm_uuid(login.to_s)

      unless temp_pass.nil?
        Rails.logger.debug("[authentication] SM using uuid: '#{login}'")

        @sm_user = temp_pass if ((not temp_pass.nil?) and (temp_pass.password == password))
      else
        Rails.logger.debug("[authentication] using login: '#{login}'")

        @current_user = ScalarmUser.authenticate_with_password(login, password)
        session[:user] = @current_user.id.to_s unless @current_user.nil?
        session[:uuid] = SecureRandom.uuid
      end

    end
  end

  def use_proxy_auth?
    not PROXY_CERT_CA.nil?
  end

  def proxy_provided?
    request.env.include?(RAILS_PROXY_HEADER)
  end

  def authenticate_with_proxy
    proxy_s = Utils::header_newlines_deserialize(request.env[RAILS_PROXY_HEADER])

    proxy = GP::Proxy.new(proxy_s)
    username = proxy.username

    if username.nil?
      Rails.logger.warn("[authentication] #{PROXY_HEADER} header present, but contains invalid data")
      return
    end

    begin
      dn = proxy.dn
      Rails.logger.debug("[authentication] using proxy certificate: '#{dn}'") # TODO: DN

      proxy.verify_for_plgrid!
      # set proxy string in instance variable for further use in PL-Grid
      @proxy_s = proxy_s

      # pass validation check, because it is already done
      @current_user = ScalarmUser.authenticate_with_proxy(proxy, false)

      if @current_user.nil?
        Rails.logger.debug "[authentication] creating new user based on proxy certificate: #{username}"
        @current_user = ScalarmUser.new(login: username, dn: dn)
        @current_user.save
      end

      session[:user] = @current_user.id.to_s unless @current_user.nil?
      session[:uuid] = SecureRandom.uuid
    rescue GP::ProxyValidationError => e
      Rails.logger.warn "[authentication] proxy validation error: #{e}"
    rescue OpenSSL::X509::CertificateError => e
      Rails.logger.warn "[authentication] OpenSSL error when trying to use proxy certificate: #{e}"
    end
  end

end