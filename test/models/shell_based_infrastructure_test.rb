require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/shell_based_infrastructure'

class ShellBasedInfrastructureTest < MiniTest::Test

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

end