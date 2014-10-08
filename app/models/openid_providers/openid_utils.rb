module OpenIDUtils
  require 'openid'
  require 'openid/extensions/ax'

  # Attribute Exchange URIs
  AX_URI = {
      user_teams: 'http://openid.plgrid.pl/userTeams',
      proxy: 'http://openid.plgrid.pl/certificate/proxy',
      user_cert: 'http://openid.plgrid.pl/certificate/userCert',
      proxy_priv_key: 'http://openid.plgrid.pl/certificate/proxyPrivKey',
      dn: 'http://openid.plgrid.pl/certificate/dn1',
      email: 'http://axschema.org/contact/email',
      name: 'http://axschema.org/namePerson',
      nickname: 'http://axschema.org/namePerson/friendly',
      first_name: 'http://axschema.org/namePerson/first',
      last_name: 'http://axschema.org/namePerson/last',
      city: 'http://axschema.org/contact/city/home',
      state: 'http://axschema.org/contact/state/home',
      website: 'http://axschema.org/contact/web/default',
      image: 'http://axschema.org/media/image/aspect11'
  }


  def self.request_ax_attributes(oidreq, attribute_aliases)
    axreq =  OpenID::AX::FetchRequest.new

    attribute_aliases.each do |attr_name|
      attr = OpenID::AX::AttrInfo.new(OpenIDUtils::AX_URI[attr_name], attr_name.to_s, true)
      attr.required = true
      axreq.add(attr)
    end

    oidreq.add_extension(axreq)
  end

  # NOTICE: only attribute_aliases from OpenIDUtils::AX_URI hash are allowed
  def self.get_ax_attributes(oidresp, attribute_aliases)
    ax_resp = OpenID::AX::FetchResponse.from_success_response(oidresp)
    attribute_aliases.each do |attr_name|
      ax_resp.aliases.add_alias(OpenIDUtils::AX_URI[attr_name], attr_name.to_s)
    end

    extension_args = ax_resp.get_extension_args
    Hash[attribute_aliases.map do |attr|
      [attr, extension_args["value.#{attr}"]]
    end]
  end

  def self.get_or_create_user_with(attribute, value, new_login=value, password=nil)
    get_user_with(attribute => value) or create_user_with(new_login, password, attribute => value)
  end

  def self.get_user_with(query)
    ScalarmUser.find_by_query(query)
  end

  def self.create_user_with(login, password, query)
    # TODO: check if login is not used?
    user_hash = { login: login }
    user = ScalarmUser.new(query.merge(user_hash))
    user.password = password if password
    user.save
    user
  end

end
