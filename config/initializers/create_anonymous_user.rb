unless Rails.env.test?
  require 'utils'

  config = Utils::load_config

  anonymous_login = config['anonymous_login']
  anonymous_password = config['anonymous_password']

  if anonymous_login and anonymous_password and not ScalarmUser.find_by_login(anonymous_login)
    Rails.logger.debug "Creating anonymous user with login: #{anonymous_login}"
    user = ScalarmUser.new(login: anonymous_login)
    user.password = anonymous_password
    user.save
  end
end