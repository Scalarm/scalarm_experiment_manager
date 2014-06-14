require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/shared_ssh'

class SSHEnabledRecordTest < MiniTest::Test

  def test_yield_ssh_session
    ssh_session = stub_everything
    ssh_session.expects(:test).once
    ssh_session.stubs(:closed?).returns(false)
    ssh_session.expects(:close).once

    record = stub_everything
    record.stubs(:_get_ssh_session).returns(ssh_session)
    record.extend(SSHEnabledRecord)

    record.ssh_session do |ssh|
      ssh.test
    end
  end

end