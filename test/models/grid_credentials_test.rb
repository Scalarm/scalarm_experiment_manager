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
end