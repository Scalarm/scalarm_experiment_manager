require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/slurm_scheduler'

class SlurmSchedulerTest < MiniTest::Test

  def setup
    @logger = stub_everything
    @record = stub_everything
    @record.stubs(:job_identifier).returns('1131597')
    @ssh = stub_everything
    @slurm = SlurmScheduler.new(@logger)
  end

  def teardown
  end

  def test_onsite_monitorable
    assert @slurm.onsite_monitorable?
  end

  def test_submit_job_success_simple
    cmd = mock 'cmd'
    output = "Submitted batch job 1131510"
    @slurm.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    parsed_id = @slurm.submit_job(@ssh, @record)

    assert_equal '1131510',  parsed_id
  end

  def test_submit_job_success_complex
    cmd = mock 'cmd'
    output = <<-eos
    TLDFA
    Submitted batch job 1131510
    e3asdasdas
    eos
    @slurm.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    parsed_id = @slurm.submit_job(@ssh, @record)

    assert_equal '1131510',  parsed_id
  end

  def test_submit_job_failed
    cmd = mock 'cmd'
    output = <<-out
its all wrong...
    out

    @slurm.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    assert_raises JobSubmissionFailed, output do
      @slurm.submit_job(@ssh, @record)
    end
  end

  def test_initializing_status_from_pending
    output = <<-OUT
    JobId=1131597 JobName=TestJob
       UserId=plgkrol(100739) GroupId=plgrid(100000)
       Priority=10840 Nice=0 Account=scalprometeus QOS=normal
       JobState=PENDING Reason=Resources Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
       RunTime=00:00:00 TimeLimit=00:01:00 TimeMin=N/A
       SubmitTime=2016-02-01T13:15:03 EligibleTime=2016-02-01T13:15:03
       StartTime=2016-02-01T14:21:53 EndTime=Unknown
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=plgrid-testing AllocNode:Sid=login01:1103
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=(null) SchedNodeList=p2042
       NumNodes=1-1 NumCPUs=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,mem=5120,node=1
       Socks/Node=* NtasksPerN:B:S:C=24:0:*:* CoreSpec=*
       MinCPUsNode=24 MinMemoryCPU=5G MinTmpDiskNode=0
       Features=(null) Gres=(null) Reservation=(null)
       Shared=OK Contiguous=0 Licenses=(null) Network=(null)
       Command=/net/people/plgkrol/test.sh
       WorkDir=/net/people/plgkrol
       StdErr=/net/people/plgkrol/test.out
       StdIn=/dev/null
       StdOut=/net/people/plgkrol/test.out
       Power= SICP=0
    OUT

    @ssh.stubs(:exec!).returns(output)

    status = @slurm.status(@ssh, @record)

    assert_equal :initializing, status
  end

  def test_initializing_status_from_configuring
    output = <<-OUT
    JobId=1131597 JobName=TestJob
       UserId=plgkrol(100739) GroupId=plgrid(100000)
       Priority=10840 Nice=0 Account=scalprometeus QOS=normal
       JobState=CONFIGURING Reason=Resources Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
       RunTime=00:00:00 TimeLimit=00:01:00 TimeMin=N/A
       SubmitTime=2016-02-01T13:15:03 EligibleTime=2016-02-01T13:15:03
       StartTime=2016-02-01T14:21:53 EndTime=Unknown
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=plgrid-testing AllocNode:Sid=login01:1103
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=(null) SchedNodeList=p2042
       NumNodes=1-1 NumCPUs=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,mem=5120,node=1
       Socks/Node=* NtasksPerN:B:S:C=24:0:*:* CoreSpec=*
       MinCPUsNode=24 MinMemoryCPU=5G MinTmpDiskNode=0
       Features=(null) Gres=(null) Reservation=(null)
       Shared=OK Contiguous=0 Licenses=(null) Network=(null)
       Command=/net/people/plgkrol/test.sh
       WorkDir=/net/people/plgkrol
       StdErr=/net/people/plgkrol/test.out
       StdIn=/dev/null
       StdOut=/net/people/plgkrol/test.out
       Power= SICP=0
    OUT

    @ssh.stubs(:exec!).returns(output)

    status = @slurm.status(@ssh, @record)

    assert_equal :initializing, status
  end

  def test_running_status_from_running
    output = <<-OUT
    JobId=1131597 JobName=TestJob
       UserId=plgkrol(100739) GroupId=plgrid(100000)
       Priority=10840 Nice=0 Account=scalprometeus QOS=normal
       JobState=RUNNING Reason=Resources Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
       RunTime=00:00:00 TimeLimit=00:01:00 TimeMin=N/A
       SubmitTime=2016-02-01T13:15:03 EligibleTime=2016-02-01T13:15:03
       StartTime=2016-02-01T14:21:53 EndTime=Unknown
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=plgrid-testing AllocNode:Sid=login01:1103
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=(null) SchedNodeList=p2042
       NumNodes=1-1 NumCPUs=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,mem=5120,node=1
       Socks/Node=* NtasksPerN:B:S:C=24:0:*:* CoreSpec=*
       MinCPUsNode=24 MinMemoryCPU=5G MinTmpDiskNode=0
       Features=(null) Gres=(null) Reservation=(null)
       Shared=OK Contiguous=0 Licenses=(null) Network=(null)
       Command=/net/people/plgkrol/test.sh
       WorkDir=/net/people/plgkrol
       StdErr=/net/people/plgkrol/test.out
       StdIn=/dev/null
       StdOut=/net/people/plgkrol/test.out
       Power= SICP=0
    OUT

    @ssh.stubs(:exec!).returns(output)

    status = @slurm.status(@ssh, @record)

    assert_equal :running, status
  end

  def test_deactivated_status_from_completing
    output = <<-OUT
    JobId=1131597 JobName=TestJob
       UserId=plgkrol(100739) GroupId=plgrid(100000)
       Priority=10840 Nice=0 Account=scalprometeus QOS=normal
       JobState=COMPLETING Reason=Resources Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
       RunTime=00:00:00 TimeLimit=00:01:00 TimeMin=N/A
       SubmitTime=2016-02-01T13:15:03 EligibleTime=2016-02-01T13:15:03
       StartTime=2016-02-01T14:21:53 EndTime=Unknown
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=plgrid-testing AllocNode:Sid=login01:1103
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=(null) SchedNodeList=p2042
       NumNodes=1-1 NumCPUs=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,mem=5120,node=1
       Socks/Node=* NtasksPerN:B:S:C=24:0:*:* CoreSpec=*
       MinCPUsNode=24 MinMemoryCPU=5G MinTmpDiskNode=0
       Features=(null) Gres=(null) Reservation=(null)
       Shared=OK Contiguous=0 Licenses=(null) Network=(null)
       Command=/net/people/plgkrol/test.sh
       WorkDir=/net/people/plgkrol
       StdErr=/net/people/plgkrol/test.out
       StdIn=/dev/null
       StdOut=/net/people/plgkrol/test.out
       Power= SICP=0
    OUT

    @ssh.stubs(:exec!).returns(output)

    status = @slurm.status(@ssh, @record)

    assert_equal :deactivated, status
  end

  def test_deactivated_status_from_completed
    output = <<-OUT
       JobId=1131597 JobName=TestJob
       UserId=plgkrol(100739) GroupId=plgrid(100000)
       Priority=10840 Nice=0 Account=scalprometeus QOS=normal
       JobState=COMPLETED Reason=Resources Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
       RunTime=00:00:00 TimeLimit=00:01:00 TimeMin=N/A
       SubmitTime=2016-02-01T13:15:03 EligibleTime=2016-02-01T13:15:03
       StartTime=2016-02-01T14:21:53 EndTime=Unknown
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=plgrid-testing AllocNode:Sid=login01:1103
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=(null) SchedNodeList=p2042
       NumNodes=1-1 NumCPUs=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,mem=5120,node=1
       Socks/Node=* NtasksPerN:B:S:C=24:0:*:* CoreSpec=*
       MinCPUsNode=24 MinMemoryCPU=5G MinTmpDiskNode=0
       Features=(null) Gres=(null) Reservation=(null)
       Shared=OK Contiguous=0 Licenses=(null) Network=(null)
       Command=/net/people/plgkrol/test.sh
       WorkDir=/net/people/plgkrol
       StdErr=/net/people/plgkrol/test.out
       StdIn=/dev/null
       StdOut=/net/people/plgkrol/test.out
       Power= SICP=0
    OUT

    @ssh.stubs(:exec!).returns(output)

    status = @slurm.status(@ssh, @record)

    assert_equal :deactivated, status
  end

  def test_deactivated_status_from_cancelled
    output = <<-OUT
    JobId=1131597 JobName=TestJob
       UserId=plgkrol(100739) GroupId=plgrid(100000)
       Priority=10840 Nice=0 Account=scalprometeus QOS=normal
       JobState=CANCELLED Reason=Resources Dependency=(null)
       Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
       RunTime=00:00:00 TimeLimit=00:01:00 TimeMin=N/A
       SubmitTime=2016-02-01T13:15:03 EligibleTime=2016-02-01T13:15:03
       StartTime=2016-02-01T14:21:53 EndTime=Unknown
       PreemptTime=None SuspendTime=None SecsPreSuspend=0
       Partition=plgrid-testing AllocNode:Sid=login01:1103
       ReqNodeList=(null) ExcNodeList=(null)
       NodeList=(null) SchedNodeList=p2042
       NumNodes=1-1 NumCPUs=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:*
       TRES=cpu=1,mem=5120,node=1
       Socks/Node=* NtasksPerN:B:S:C=24:0:*:* CoreSpec=*
       MinCPUsNode=24 MinMemoryCPU=5G MinTmpDiskNode=0
       Features=(null) Gres=(null) Reservation=(null)
       Shared=OK Contiguous=0 Licenses=(null) Network=(null)
       Command=/net/people/plgkrol/test.sh
       WorkDir=/net/people/plgkrol
       StdErr=/net/people/plgkrol/test.out
       StdIn=/dev/null
       StdOut=/net/people/plgkrol/test.out
       Power= SICP=0
    OUT

    @ssh.stubs(:exec!).returns(output)

    status = @slurm.status(@ssh, @record)

    assert_equal :deactivated, status
  end

  def test_deactivated_status_from_cancelled_and_removed
    scontrol_output = "slurm_load_jobs error: Invalid job id specified"
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('scontrol show job') }.returns(scontrol_output)

    sacct_output = <<-OUT
    JobID    JobName  Partition    Account  AllocCPUS      State ExitCode
------------ ---------- ---------- ---------- ---------- ---------- --------
1131597         TestJob plgrid-te+ scalprome+          1 CANCELLED+      0:0
    OUT
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('sacct -j') }.returns(sacct_output)


    status = @slurm.status(@ssh, @record)

    assert_equal :deactivated, status
  end

  def test_error_status_from_failed
    scontrol_output = "slurm_load_jobs error: Invalid job id specified"
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('scontrol show job') }.returns(scontrol_output)

    sacct_output = <<-OUT
    JobID    JobName  Partition    Account  AllocCPUS      State ExitCode
------------ ---------- ---------- ---------- ---------- ---------- --------
1131597         TestJob plgrid-te+ scalprome+          1  FAILED      0:0
    OUT
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('sacct -j') }.returns(sacct_output)

    status = @slurm.status(@ssh, @record)

    assert_equal :error, status
  end

  def test_error_status_from_node_fail
    scontrol_output = "slurm_load_jobs error: Invalid job id specified"
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('scontrol show job') }.returns(scontrol_output)

    sacct_output = <<-OUT
    JobID    JobName  Partition    Account  AllocCPUS      State ExitCode
------------ ---------- ---------- ---------- ---------- ---------- --------
1131597         TestJob plgrid-te+ scalprome+          1  NODE_FAIL      0:0
    OUT
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('sacct -j') }.returns(sacct_output)


    status = @slurm.status(@ssh, @record)

    assert_equal :error, status
  end

  def test_error_status_from_preempted
    scontrol_output = "slurm_load_jobs error: Invalid job id specified"
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('scontrol show job') }.returns(scontrol_output)

    sacct_output = <<-OUT
    JobID    JobName  Partition    Account  AllocCPUS      State ExitCode
------------ ---------- ---------- ---------- ---------- ---------- --------
1131597         TestJob plgrid-te+ scalprome+          1   PREEMPTED      0:0
    OUT
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('sacct -j') }.returns(sacct_output)


    status = @slurm.status(@ssh, @record)

    assert_equal :error, status
  end

  def test_error_status_from_suspended
    scontrol_output = "slurm_load_jobs error: Invalid job id specified"
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('scontrol show job') }.returns(scontrol_output)

    sacct_output = <<-OUT
    JobID    JobName  Partition    Account  AllocCPUS      State ExitCode
------------ ---------- ---------- ---------- ---------- ---------- --------
1131597         TestJob plgrid-te+ scalprome+          1    SUSPENDED      0:0
    OUT
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('sacct -j') }.returns(sacct_output)


    status = @slurm.status(@ssh, @record)

    assert_equal :error, status
  end

  def test_error_status_from_timeout
    scontrol_output = "slurm_load_jobs error: Invalid job id specified"
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('scontrol show job') }.returns(scontrol_output)

    sacct_output = <<-OUT
    JobID    JobName  Partition    Account  AllocCPUS      State ExitCode
------------ ---------- ---------- ---------- ---------- ---------- --------
1131597         TestJob plgrid-te+ scalprome+          1     TIMEOUT      0:0
    OUT
    @ssh.stubs(:exec!).with{ |*args| args[0].include?('sacct -j') }.returns(sacct_output)


    status = @slurm.status(@ssh, @record)

    assert_equal :error, status
  end

  def test_job_description_with_params
    desc = @slurm.prepare_job_descriptor('1', {
      'grant_id' => 'testowy',
      'nodes' => 2,
      'time_limit' => (55*60) + 30,
      'ppn' => 8,
      'memory' => 2048,
      'queue_name' => 'plgrid',
      'memory' => 2048
    })

    assert_match /#SBATCH -N 2/, desc
    assert_match /#SBATCH -A testowy/, desc
    assert_match /#SBATCH --time=3330/, desc
    assert_match /#SBATCH -p plgrid/, desc
    assert_match /#SBATCH --mem=2048/, desc
  end

end
