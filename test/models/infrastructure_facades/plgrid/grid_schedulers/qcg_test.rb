require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/grid_schedulers/qcg'

class QcgTest < MiniTest::Test

  def setup
    @logger = stub_everything
    @record = stub_everything
    @ssh = stub_everything
    @qcg = QcgScheduler::PlGridScheduler.new(@logger)
  end

  def teardown
  end

  def test_parse_job_id
    output = <<-eos
httpg://qcg-broker.man.poznan.pl:8443/qcg/services/
/C=PL/O=GRID/O=PSNC/CN=qcg-broker/qcg-broker.man.poznan.pl
Your identity: C=PL,O=PL-Grid,O=Uzytkownik,O=AGH,CN=Jakub Liput,CN=plgjliput
Creating proxy, please wait...
Proxy verify OK
Your proxy is valid until Sat Jun 28 13:39:22 CEST 2014
UserDN = /C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput
ProxyLifetime = 24 Days 23 Hours 59 Minutes 50 Seconds

qcg_test_jl.qcg 0       jobId = J1401795580484__1245
    eos

    assert_equal 'J1401795580484__1245',  QcgScheduler::PlGridScheduler.parse_job_id(output)
  end

  def test_parse_status
    output = <<-eos
httpg://qcg-broker.man.poznan.pl:8443/qcg/services/
/C=PL/O=GRID/O=PSNC/CN=qcg-broker/qcg-broker.man.poznan.pl
UserDN = /C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput
ProxyLifetime = 24 Days 23 Hours 58 Minutes 32 Seconds

J1401795580484__1245 :
Note:
UserDN: /C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput
TaskType: SINGLE
SubmissionTime: Tue Jun 03 13:39:40 CEST 2014
FinishTime:
ProxyLifetime: P24DT23H58M17S
Status: PENDING
StatusDesc:
StartTime: Tue Jun 03 13:39:41 CEST 2014
Purged: false

Allocation:
HostName: zeus.cyfronet.pl
ProcessesCount: 1
ProcessesGroupId:
Status: PENDING
StatusDescription:
SubmissionTime: Tue Jun 03 13:39:40 CEST 2014
FinishTime:
LocalSubmissionTime: Tue Jun 03 13:39:42 CEST 2014
LocalStartTime:
LocalFinishTime:
Purged: false


    eos

    assert_equal 'PENDING', QcgScheduler::PlGridScheduler.parse_qcg_state(output)

  end

  def test_parse_status_desc
    output = <<-eos
httpg://qcg-broker.man.poznan.pl:8443/qcg/services/
/C=PL/O=GRID/O=PSNC/CN=qcg-broker/qcg-broker.man.poznan.pl
UserDN = /C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput
ProxyLifetime = 24 Days 23 Hours 40 Minutes 53 Seconds

J1401795580484__1245 :
Note:
UserDN: /C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput
TaskType: SINGLE
SubmissionTime: Tue Jun 03 13:39:40 CEST 2014
FinishTime: Tue Jun 03 13:41:30 CEST 2014
ProxyLifetime: P24DT23H40M38S
Status: FAILED
StatusDesc: Subtask from host 'zeus.cyfronet.pl' failed
StartTime: Tue Jun 03 13:39:41 CEST 2014
Purged: false

Allocation:
HostName: zeus.cyfronet.pl
ProcessesCount: 1
ProcessesGroupId:
Status: FAILED
StatusDescription: failed to transfer [/mnt/lustre/scratch/people//plgjliput/J1401795580484__1245_task_1401795580924_941/stdout] -> [/mnt/auto/people/plgjliput/qcg/out/J1401795580484__1245.log]: No such file or directory /mnt/auto/people/plgjliput/qcg/out/J1401795580484__1245.log; failed to transfer [/mnt/lustre/scratch/people//plgjliput/J1401795580484__1245_task_1401795580924_941/stderr] -> [/mnt/auto/people/plgjliput/qcg/out/J1401795580484__1245.log]: No such file or directory /mnt/auto/people/plgjliput/qcg/out/J1401795580484__1245.log
SubmissionTime: Tue Jun 03 13:39:40 CEST 2014
FinishTime: Tue Jun 03 13:43:36 CEST 2014
LocalSubmissionTime: Tue Jun 03 13:39:42 CEST 2014
LocalStartTime: Tue Jun 03 13:41:30 CEST 2014
LocalFinishTime: Tue Jun 03 13:41:30 CEST 2014
Purged: false

    eos

    desc = 'Subtask from host \'zeus.cyfronet.pl\' failed'

    assert_equal desc, QcgScheduler::PlGridScheduler.parse_qcg_status_desc(output)

  end

  def test_queue_plgrid_testing
    desc = @qcg.prepare_job_descriptor('1', 'time_limit' => '10')
    assert_match /queue=plgrid-testing/, desc
  end

  def test_queue_plgrid
    desc = @qcg.prepare_job_descriptor('1', 'time_limit' => '80')
    assert_match /queue=plgrid/, desc
  end

  def test_queue_plgrid_long
    desc = @qcg.prepare_job_descriptor('1', 'time_limit' => (73*60).to_s)
    assert_match /queue=plgrid-long/, desc
  end

  def test_minutes_to_walltime
    assert_equal 'P0DT2H5M', QcgScheduler::PlGridScheduler.minutes_to_walltime(125)
    assert_equal 'P2DT12H54M', QcgScheduler::PlGridScheduler.minutes_to_walltime(3654)
  end

  def test_walltime
    desc = @qcg.prepare_job_descriptor('1', 'time_limit' => 3654.to_s)
    assert_match /walltime=P2DT12H54M/, desc
  end

  def test_nodes_cores
    desc = @qcg.prepare_job_descriptor('1', 'nodes' => '4', 'ppn' => '12')
    assert_match /#QCG nodes=4:12/, desc
  end

  def test_blank_nodes_cores
    desc = @qcg.prepare_job_descriptor('1', {})
    refute_match /#QCG nodes/, desc
  end

  def test_grant_id
    desc = @qcg.prepare_job_descriptor('1', 'grant_id' => 'plgtest2014a')
    assert_match /#QCG grant=plgtest2014a/, desc
  end

  def test_grant_id_blank
    desc = @qcg.prepare_job_descriptor('1', 'grant_id' => '')
    refute_match /#QCG grant/, desc
  end

  def test_onsite_monitorable
    assert @qcg.onsite_monitorable?
  end

  def test_submit_job
    cmd = mock 'cmd'
    output = <<-out
httpg://qcg-broker.man.poznan.pl:8443/qcg/services/
/C=PL/O=GRID/O=PSNC/CN=qcg-broker/qcg-broker.man.poznan.pl
Enter GRID pass phrase for this identity:
UserDN = /C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput
ProxyLifetime = 24 Days 23 Hours 59 Minutes 59 Seconds

qcg_test_jl.qcg {}      jobId = J1416336702195__9651
    out

    @qcg.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    parsed_id = @qcg.submit_job(@ssh, @record)

    assert_equal 'J1416336702195__9651', parsed_id
  end

  def test_submit_job_failed
    cmd = mock 'cmd'
    output = <<-out
its all wrong...
    out

    @qcg.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    assert_raises JobSubmissionFailed, output do
      @qcg.submit_job(@ssh, @record)
    end
  end

end