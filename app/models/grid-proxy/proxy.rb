module GP
  class Proxy
    CERT_START = '-----BEGIN CERTIFICATE-----'

    attr_reader :proxy_payload

    def initialize(proxy_payload, username_prefix = 'plg')
      @proxy_payload = proxy_payload
      @username_prefix = username_prefix
    end

    def proxycert
      @proxycert ||= cert_for_element(1)
    end

    def proxykey
      begin
        @proxykey ||= OpenSSL::PKey.read(proxy_element(1))
      rescue
        nil
      end
    end

    def usercert
      @usercert ||= cert_for_element(2)
    end

    def verify!(ca_cert_payload, crl_payload = nil)
      now = Time.now
      raise GP::ProxyValidationError.new('Proxy is not valid yet') if now < proxycert.not_before
      raise GP::ProxyValidationError.new('Proxy expired') if now > proxycert.not_after
      raise GP::ProxyValidationError.new('Usercert not signed with trusted certificate') unless ca_cert_payload && usercert.verify(cert(ca_cert_payload).public_key)
      raise GP::ProxyValidationError.new('Proxy not signed with user certificate') unless proxycert.verify(usercert.public_key)

      proxycert_issuer = proxycert.issuer.to_s
      proxycert_subject = proxycert.subject.to_s

      raise GP::ProxyValidationError.new('Proxy and user cert mismatch') unless proxycert_issuer == usercert.subject.to_s
      raise GP::ProxyValidationError.new("Proxy subject must begin with the issuer") unless proxycert_subject.to_s.index(proxycert_issuer) == 0
      raise GP::ProxyValidationError.new("Couldn't find '/CN=' in DN, not a proxy") unless proxycert_subject.to_s[proxycert_issuer.size, proxycert_subject.to_s.size].to_s.include?('/CN=')

      raise GP::ProxyValidationError.new("Private proxy key missing") unless proxykey
      raise GP::ProxyValidationError.new("Private proxy key and cert mismatch") unless proxycert.check_private_key(proxykey)

      raise GP::ProxyValidationError.new("User cert was revoked") if crl_payload != nil and revoked? crl_payload
    end

    def valid?(ca_cert_payload, crl_payload = nil)
      begin
        verify! ca_cert_payload, crl_payload
        true
      rescue GP::ProxyValidationError => e
        false
      end
    end

    def revoked?(crl_payload)
      # crl should to be verified with ca cert
      # crl(crl_payload).verify()

      #check for usercert serial in list of all revoked certs
      revoked_cert = crl(crl_payload).revoked().detect do |revoked|
        revoked.serial == usercert.serial
      end

      return revoked_cert != nil ? true : false

    end

    def username
      username_entry = usercert.subject.to_a.detect do |el|
        el[0] == 'CN' && el[1].start_with?(@username_prefix)
      end

      username_entry ? username_entry[1] : nil
    end

    private

    def cert_for_element(element_nr)
      cert(proxy_element(element_nr))
    end

    def proxy_element(element_nr)
      "#{CERT_START}#{@proxy_payload.split(CERT_START)[element_nr]}"
    end

    def cert(payload)
      OpenSSL::X509::Certificate.new payload
    end

    def crl(payload)
      OpenSSL::X509::CRL.new payload
    end
  end
end
