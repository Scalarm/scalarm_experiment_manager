require 'rest-client'

module GithubOauth
  require 'openid_providers/openid_utils'

  GITHUB_AUTHORIZATION_URL = 'https://github.com/login/oauth/authorize?scope=user:email&client_id='
  GITHUB_ACCESS_TOKEN_URL = 'https://github.com/login/oauth/access_token'
  GITHUB_USER_INFO_URL = 'https://api.github.com/user/emails'

  def login_oauth_github
    if Rails.application.secrets.include?(:github_client_id) and Rails.application.secrets.include?(:github_client_secret)
      redirect_to GITHUB_AUTHORIZATION_URL + Rails.application.secrets.github_client_id
    else
      Rails.logger.warn(t 'oauth.no_github_secrets')
      flash[:error] = t 'oauth.no_github_secrets'
      redirect_to root_path
    end
  end

  # TODO no error handling
  def oauth2_github_callback
    if params.include? 'code'
      begin
        user_info = get_user_info_from_github params['code']

        if not user_info.nil?
          user_info = user_info.first
          if user_info.include?('email')
            user = OpenIDUtils::get_or_create_user_with(:email, user_info['email'])

            flash[:notice] = t('openid.verification_success', identity: user_info['email'])
            session[:user] = user.id.to_s
            session[:uuid] = SecureRandom.uuid

            successful_login
          else
            Rails.logger.debug(t 'oauth.no_email_provided')
            flash[:error] = t 'oauth.no_email_provided'
          end
        end
      rescue => e
        Rails.logger.error(t('oauth.error_occured', error: e.message))
        flash[:error] = t('oauth.error_occured', error: e.message)
      end
    end

    redirect_to login_path if not session.include? :user
  end

  private

  # returns a hash with user info, a nil or throws an exception
  def get_user_info_from_github(auth_code)
    result = RestClient.post(GITHUB_ACCESS_TOKEN_URL,
                             {
                              client_id: Rails.application.secrets.github_client_id,
                              client_secret: Rails.application.secrets.github_client_secret,
                              code: auth_code,
                              scope: 'user,user:email'
                             }, accept: :json)
    result = JSON.parse(result)

    info = RestClient.get(GITHUB_USER_INFO_URL, { params: { access_token: result['access_token'] } })

    JSON.parse(info)
  end

  def self.github_configured?
    Rails.application.secrets.include?(:github_client_id) and Rails.application.secrets.include?(:github_client_secret)
  end

end