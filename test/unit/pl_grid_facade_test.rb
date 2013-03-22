require 'test_helper'
require 'securerandom'
#require 'pl_grid_facade'


class PLGridFacadeTest < ActiveSupport::TestCase
  test 'preparation of job descriptor' do

     assert true
  end
end



#class PLGridFacadeTest < Test::Unit::TestCase
#
#  # Called before every test method runs. Can be used
#  # to set up fixture information.
#  def setup
#    # Do nothing
#  end
#
#  # Called after every test method runs. Can be used to tear
#  # down fixture information.
#
#  def teardown
#    # Do nothing
#  end
#
#  def test_preparation_of_job_descriptor
#    uuid = SecureRandom.uuid
#
#    should_be = <<-eos
#      Executable = "scalarm_job_#{uuid}.sh";
#      Arguments = "";
#      StdOutput = "scalarm_job.out";
#      StdError = "scalarm_job.err";
#      OutputSandbox = {"scalarm_job.out", "scalarm_job.err"};
#      InputSandbox = {"scalarm_job_#{uuid}.sh", "scalarm_simulation_manager_#{uuid}.zip"};
#      Requirements = other.GlueCEUniqueID == "cream.grid.cyf-kr.edu.pl:8443/cream-pbs-plgrid";
#    eos
#
#    assert_equal(should_be, PLGridFacade.new.prepare_job_descriptor(uuid))
#  end
#
#end