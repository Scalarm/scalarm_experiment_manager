require 'scalarm/service_core/configuration'

CRL_REFRESH_TIME = 4.hours unless defined? CRL_REFRESH_TIME

custom_proxy_ca = Rails.application.secrets.proxy_cert_ca
custom_proxy_crl = Rails.application.secrets.proxy_cert_crl

if custom_proxy_ca
  slog('proxy', "Using custom proxy CA: #{custom_proxy_ca}")
  Scalarm::ServiceCore::Configuration.load_proxy_ca(custom_proxy_ca)
end

if custom_proxy_crl
  slog('proxy', "Using custom proxy CRL: #{custom_proxy_crl}")

  ## Will use start_crl_auto_uptade instead
  # Scalarm::ServiceCore::Configuration.load_proxy_crl(custom_proxy_crl)

  t = Scalarm::ServiceCore::Configuration.start_crl_auto_update(Rails.application.secrets.proxy_cert_crl, CRL_REFRESH_TIME)
  at_exit { t.terminate }
end
