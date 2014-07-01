module UserControllerHelper

  def credentials_state(credentials, user, infrastructure_name)
    if user.banned_infrastructure?(infrastructure_name)
      'banned'
    elsif credentials
      if credentials.invalid
        'invalid'
      else
        'ok'
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

  def openid_callback_plgrid_url
    url_for :action => 'openid_callback_plgrid', :only_path => false
  end

end
