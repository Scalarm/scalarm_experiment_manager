require 'scalarm/service_core/configuration'

custom_proxy_ca = Rails.application.secrets.proxy_cert_ca
custom_proxy_crl = Rails.application.secrets.proxy_cert_crl

if custom_proxy_ca
  slog('proxy', "Using custom proxy CA: #{custom_proxy_ca}")
  Scalarm::ServiceCore::Configuration.load_proxy_ca(custom_proxy_ca)
end

if custom_proxy_crl
  slog('proxy', "Using custom proxy CRL: #{custom_proxy_crl}")
  Scalarm::ServiceCore::Configuration.load_proxy_crl(custom_proxy_crl)
end
