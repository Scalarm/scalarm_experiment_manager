module UserControllerHelper

  # --- OpenID helpers ---

  def login_openid_google_url
    url_for :action => 'login_openid_google', :only_path => false
  end

  def openid_callback_google_url
    url_for :action => 'openid_callback_google', :only_path => false
  end
end
