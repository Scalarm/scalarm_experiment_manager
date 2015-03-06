require "grid-proxy/version"
require "grid-proxy/proxy"
require "grid-proxy/exceptions"

# Scalarm extensions

module GP
  class Proxy
    def verify_for_plgrid!
      crl = nil # TODO CRL
      ca = File.read('/etc/grid-security/certificates/afed687d.0')
      #ca = File.read('/etc/grid-security/certificates/PolishGrid.pem') # TODO load earlier, config
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
  end
end