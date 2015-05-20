require "grid-proxy/version"
require "grid-proxy/proxy"
require "grid-proxy/exceptions"

# Scalarm extensions

module GP
  class Proxy
    def verify_for_plgrid!
      crl = nil # TODO CRL
      ca = PROXY_CERT_CA
      verify!(ca, crl)
    end

    def valid_for_plgrid?
      begin
        verify_for_plgrid!
        true
      rescue GP::ProxyValidationError => e
        false
      end
    end

    def dn
      proxycert.issuer.to_s
    end
  end
end