# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
    :password, :current_password, :password_repeat, 'key_passphrase',
    'openid.ext1.value.user_cert', 'openid.ext1.value.proxy', 'openid.ext1.value.proxy_priv_key'
]
