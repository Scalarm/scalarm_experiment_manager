require 'minitest/autorun'
require 'test_helper'

class BashCommandTest < MiniTest::Test

  def test_single_command
    assert_equal BashCommand.new.cd('folder').to_s, "/bin/bash -i -c 'cd folder'"
  end

  def test_chained_commands
    assert_equal BashCommand.new.cd('folder').rm('file').to_s, "/bin/bash -i -c 'cd folder;rm  file'"
  end

  def test_muted_command
    assert_equal BashCommand.new.cd('folder').muted_rm('file').to_s, "/bin/bash -i -c 'cd folder;rm  file >/dev/null 2>&1'"
  end

end