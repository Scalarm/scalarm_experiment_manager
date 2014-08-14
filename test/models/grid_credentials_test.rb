require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class GridCredentialsTest < MiniTest::Test

  def setup
    Rails.stubs(:logger).returns(stub_everything)
  end

  def test_ssh
    require 'net/ssh'
    Net::SSH.expects(:start).once.with('test_host', 'test_login', {password: 'test_password'}).once

    credentials = GridCredentials.new('host'=>'test_host')
    credentials.login = 'test_login'
    credentials.password = 'test_password'

    credentials.ssh_session
  end

  def test_scp
    require 'net/scp_ext'
    Net::SCP.expects(:start).once.with('test_host', 'test_login', {password: 'test_password'}).once

    credentials = GridCredentials.new('host'=>'test_host')
    credentials.login = 'test_login'
    credentials.password = 'test_password'

    credentials.scp_session
  end

  def test_ssh_unavailable
    require 'infrastructure_facades/infrastructure_errors'
    credentials = GridCredentials.new(host: 'test_host', login: 'test_login')
    assert_raises InfrastructureErrors::NoCredentialsError do
      credentials.ssh_session
    end
  end

  def test_ssh_proxy
    require 'gsi/ssh'
    Gsi::SSH.expects(:start).once.with('test_host', 'test_login', 'proxy_content').once

    credentials = GridCredentials.new(host: 'test_host', login: 'test_login', secret_proxy: 'proxy_content')

    credentials.ssh_session
  end

  def test_remove_invalid_proxy_when_no_password
    host = mock 'host'
    login = mock 'login'
    proxy = mock 'proxy'

    credentials = GridCredentials.new(
        secret_proxy: proxy,
        login: login,
        host: host
    )

    Gsi::SSH.expects(:start).with(host, login, proxy).once.raises(Gsi::ProxyError)
    credentials.expects(:secret_proxy=).with(nil).once
    credentials.expects(:save).once

    assert_raises Gsi::ProxyError do
      credentials._get_ssh_session
    end
  end

end