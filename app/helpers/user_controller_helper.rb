require 'securerandom'

module UserControllerHelper

  def credentials_state(credentials, user, infrastructure_name)
    if user.banned_infrastructure?(infrastructure_name)
      'banned'
    elsif credentials
      if credentials.invalid
        'invalid'
      else
        # TODO: should be delegated somewhere...
        case infrastructure_name
          when 'qsub'
            (credentials.secret_proxy and 'proxy') or (credentials.password and 'ok') or 'not-in-db'
          when 'pl_cloud'
            (credentials.secret_proxy and 'proxy') or (credentials.secret_password and 'ok') or 'not-in-db'
          else
            'ok'
        end
      end
    else
      'not-in-db'
    end
  end

  def welcome_link(url, icon_id)
    content_tag :a, href: url do
      content_tag :span, class: 'button radius last-element secondary' do
        icon icon_id
      end
    end
  end

  # --- OpenID helpers ---

  def login_openid_google_url
    url_for :action => 'login_openid_google', :only_path => false
  end

  def openid_callback_google_url
    url_for :action => 'openid_callback_google', :only_path => false
  end

  def login_openid_plgrid_url
    url_for :action => 'login_openid_plgrid', :only_path => false
  end

  def openid_callback_plgrid_url(temp_pass=nil)
    url_for action: 'openid_callback_plgrid', only_path: false, params: (temp_pass ? {temp_pass: temp_pass} : {})
  end

  def github_configured?
    GithubOauth.github_configured?
  end

  def google_configured?
    GoogleOpenID.google_configured?
  end

  # TODO: SCAL-936 - enable/disable PL-Grid
  def plgrid_enabled?
    true
  end

  # TODO: SCAL-936 - enable/disable PL-Grid
  def basicauth_enabled?
    true
  end

end
