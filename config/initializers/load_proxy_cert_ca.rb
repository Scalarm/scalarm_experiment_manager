if Rails.application.secrets.proxy_cert_ca.blank?
  Rails.logger.warn('Proxy certificate CA path not provided - proxy authentication will be disabled')
  PROXY_CERT_CA = nil
else
  PROXY_CERT_CA = File.read(Rails.application.secrets.proxy_cert_ca)
  begin
    # check if provided file contains certificate (TODO: it is not validated)
    ce = OpenSSL::X509::Certificate.new(PROXY_CERT_CA)
  rescue OpenSSL::X509::CertificateError => error
    Rails.logger.error("OpenSSL error on loading proxy CA: #{error}")
  end
end
