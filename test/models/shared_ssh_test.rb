require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'infrastructure_facades/shared_ssh'

class SharedSshTest < MiniTest::Test

  class MockFacade
    include SharedSSH
  end

  def setup
    MockFacade.any_instance.stubs(:logger).returns(stub_everything)
  end

  def test_shared_session
    session_a_mock = mock do
      stubs(:closed?).returns(false)
    end

    credentials_a = mock do
      expects(:ssh_session).returns(session_a_mock).twice # second time will be invoked after closing session
      expects(:id).returns('credentials_a').at_least_once
    end

    session_b_mock = mock do
      stubs(:closed?).returns(false)
    end

    credentials_b = mock do
      expects(:ssh_session).returns(session_b_mock).once
      expects(:id).returns('credentials_b').at_least_once
    end

    facade = MockFacade.new

    assert_equal({}, facade.ssh_sessions)

    session_a1 = facade.shared_ssh_session(credentials_a)

    assert_equal session_a_mock, session_a1
    assert_equal({credentials_a.id=>session_a1}, facade.ssh_sessions)

    session_a2 = facade.shared_ssh_session(credentials_a)
    assert_equal session_a1, session_a2
    assert_equal({credentials_a.id=>session_a2}, facade.ssh_sessions)

    # closing session
    session_a_mock.stubs(:closed?).returns(true)

    session_a3 = facade.shared_ssh_session(credentials_a)
    # creation of new session should be invoked...
    session_a_mock.stubs(:closed?).returns(false)
    assert_equal session_a1, session_a3

    # other credentials
    session_b1 = facade.shared_ssh_session(credentials_b)
    assert_equal session_b_mock, session_b1
    assert_equal({credentials_a.id=>session_a1, credentials_b.id=>session_b1}, facade.ssh_sessions)

  end
end