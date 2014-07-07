require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/shell_based_infrastructure'
include ShellBasedInfrastructure

class ShellBasedInfrastructureTest < MiniTest::Test

  class DummyShellBasedInfrastructure
    include ShellBasedInfrastructure
  end

  def test_output_to_pid
    output = <<-OUT
42
ruby/2.1.1' load complete.
20257

    OUT

    assert_equal 20257, ShellBasedInfrastructure.output_to_pid(output)
  end

  def test_output_to_pid_inline
    output = <<-OUT
ruby/2.1.1' load complete. 9871
    OUT

    pid = ShellBasedInfrastructure.output_to_pid(output)
    refute_equal 9871, pid, pid
  end

  def test_send_and_launch_sm
    pid = mock 'pid'
    output = mock 'output'
    command = mock 'command'

    record = stub_everything 'record' do
      expects(:pid=).with(pid).returns(pid)
      expects(:upload_file).once
    end

    ShellBasedInfrastructure.stubs(:start_simulation_manager_cmd).with(record).returns(command)
    ShellBasedInfrastructure.expects(:output_to_pid).with(output).returns(pid)
    DummyShellBasedInfrastructure.any_instance.stubs(:logger).returns(stub_everything)

    ssh = stub_everything 'ssh' do
      expects(:exec!).with(command).returns(output)
    end

    infrastructure = DummyShellBasedInfrastructure.new

    launch_output = infrastructure.send_and_launch_sm(record, ssh)

    assert_equal pid, launch_output
  end

end