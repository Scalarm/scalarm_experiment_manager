module OpenIDUtils

  # constants
  AX_URI = {
      # email: 'http://schema.openid.net/contact/email',
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

  AX_EMAIL_URI = 'http://schema.openid.net/contact/email'
  AX_EMAIL_ALIAS = 'email'

end
