require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class GridCredentialsTest < MiniTest::Test

  def setup
  end

  def teardown
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
    require 'net/scp'
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

    credentials = GridCredentials.new(host: 'test_host', login: 'test_login', proxy: 'proxy_content')

    credentials.ssh_session
  end
end