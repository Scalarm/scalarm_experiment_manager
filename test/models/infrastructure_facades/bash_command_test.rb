require 'minitest/autorun'
require 'test_helper'

require 'infrastructure_facades/shell_based_infrastructure'
include ShellBasedInfrastructure

require 'infrastructure_facades/bash_command'

class BashCommandTest < MiniTest::Test

  def test_change_dir
    target_dir = RemoteDir::scalarm_root

    bash_cmd = BashCommand.new.cd(target_dir).to_s

    assert_equal "/bin/bash -i -c 'cd #{target_dir}'", bash_cmd
  end

  def test_command_chaining
    cmd1 = "unxz -f #{ScalarmFileName::monitoring_package}"
    cmd2 = "chmod a+x #{ScalarmFileName::monitoring_binary}"

    bash_cmd = BashCommand.new.append(cmd1).append(cmd2).to_s

    assert_equal "/bin/bash -i -c '#{cmd1};#{cmd2}'", bash_cmd
  end

  def test_muting_and_logging
    cmd1 = "unxz -f #{ScalarmFileName::monitoring_package}"
    cmd2 = "chmod a+x #{ScalarmFileName::monitoring_binary}"
    log_file_path = "/tmp/somewhere"

    bash_cmd = BashCommand.new.mute(cmd1).log(cmd2, log_file_path).to_s

    assert_equal "/bin/bash -i -c '#{cmd1} >/dev/null 2>&1;#{cmd2} >/tmp/somewhere 2>&1'", bash_cmd
  end

  def test_muting_last_and_logging_last
    cmd1 = "unxz -f #{ScalarmFileName::monitoring_package}"
    cmd2 = "chmod a+x #{ScalarmFileName::monitoring_binary}"
    log_file_path = "/tmp/somewhere"

    bash_cmd = BashCommand.new.append(cmd1).mute_last_command.append(cmd2).log_last_command(log_file_path).to_s

    assert_equal "/bin/bash -i -c '#{cmd1} >/dev/null 2>&1;#{cmd2} >/tmp/somewhere 2>&1'", bash_cmd
  end

  def test_running_background_commands
    cmd1 = "unxz -f #{ScalarmFileName::monitoring_package}"

    cmd2 = "./#{ScalarmFileName::monitoring_binary} #{ScalarmFileName::monitoring_config}"
    cmd2_stdout = "#{ScalarmFileName::monitoring_binary}_`date +%Y-%m-%d_%H-%M-%S-$(expr $(date +%N) / 1000000)`.log"

    bash_cmd = BashCommand.new.append(cmd1).run_in_background(cmd2, cmd2_stdout).to_s

    assert_equal "/bin/bash -i -c '#{cmd1};nohup #{cmd2} >#{cmd2_stdout} 2>&1 & echo $! 2>/dev/null'", bash_cmd
  end

end