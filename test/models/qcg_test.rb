require 'test/unit'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/grid_schedulers/qcg'

class QcgTest < Test::Unit::TestCase

  def setup
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
    qcg = QcgScheduler::PlGridScheduler.new
    desc = qcg.prepare_job_descriptor('1', 'time_limit' => '10')
    assert_match /queue=plgrid-testing/, desc
  end

  def test_queue_plgrid
    qcg = QcgScheduler::PlGridScheduler.new
    desc = qcg.prepare_job_descriptor('1', 'time_limit' => '80')
    assert_match /queue=plgrid/, desc
  end

  def test_queue_plgrid_long
    qcg = QcgScheduler::PlGridScheduler.new
    desc = qcg.prepare_job_descriptor('1', 'time_limit' => (73*60).to_s)
    assert_match /queue=plgrid-long/, desc
  end

  def test_minutes_to_walltime
    assert_equal 'P0DT2H5M', QcgScheduler::PlGridScheduler.minutes_to_walltime(125)
    assert_equal 'P2DT12H54M', QcgScheduler::PlGridScheduler.minutes_to_walltime(3654)
  end

  def test_walltime
    qcg = QcgScheduler::PlGridScheduler.new
    desc = qcg.prepare_job_descriptor('1', 'time_limit' => 3654.to_s)
    assert_match /walltime=P2DT12H54M/, desc
  end

end