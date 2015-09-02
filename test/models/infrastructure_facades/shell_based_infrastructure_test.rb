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

  def test_short_output_to_pid
    output = '20257'

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
    stripped_output = mock 'stripped output'
    command = mock 'command'

    record = stub_everything 'record' do
      expects(:pid=).with(pid).returns(pid)
      expects(:upload_file).once
    end

    ShellBasedInfrastructure.expects(:strip_pid_output).with(output).returns(stripped_output)
    ShellBasedInfrastructure.stubs(:start_simulation_manager_cmd).with(record).returns(command)
    ShellBasedInfrastructure.expects(:output_to_pid).with(stripped_output).returns(pid)
    DummyShellBasedInfrastructure.any_instance.stubs(:logger).returns(stub_everything)

    ssh = stub_everything 'ssh' do
      expects(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(command)).returns(output)
    end

    infrastructure = DummyShellBasedInfrastructure.new

    launch_output = infrastructure.send_and_launch_sm(record, ssh)

    assert_equal pid, launch_output
  end

  # check if sim start cmd for :go is not empty and does not raise anything
  def test_start_simulation_manager_cmd_pass
    record = mock 'record' do
      stubs(:sm_uuid).returns('sm_uuid')
      stubs(:absolute_log_path).returns('some.log')
    end

    configuration = mock 'configuration' do
      stubs(:simulation_manager_version).returns(:go)
    end
    Rails.stubs(:configuration).returns(configuration)

    refute_empty ShellBasedInfrastructure.start_simulation_manager_cmd(record)
  end

end