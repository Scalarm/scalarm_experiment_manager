require 'test_helper'
require 'minitest/autorun'
require 'mocha/mini_test'


require 'infrastructure_facades/plgrid/grid_schedulers/qsub'

class QsubTest < MiniTest::Test

  def setup
    @logger = stub_everything
    @ssh = stub_everything
    @record = stub_everything
    @qsub = QsubScheduler::PlGridScheduler.new(@logger)
  end

  def test_onsite_monitorable
    assert @qsub.onsite_monitorable?
  end

  def test_submit_job
    cmd = mock 'cmd'
    output = <<-out
argument-check: Setting grant ID to default grant ID (plgjliput2014b).
54105429.batch.grid.cyf-kr.edu.pl
    out

    @qsub.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    parsed_id = @qsub.submit_job(@ssh, @record)

    assert_equal '54105429.batch.grid.cyf-kr.edu.pl', parsed_id
  end

  def test_submit_job_failed
    cmd = mock 'cmd'
    output = <<-out
argument-check: Setting grant ID to default grant ID (plgjliput2014b).


------------------------------  UWAGA -----------------------------------------
Używasz starego systemu scratch

Od dnia 15.11.2014 obliczenia w lokalizacji /mnt/lustre/scratch nie są wspierane
w związku z wycofywaniem starego systemu scratch.

Aby przełączyć się na nową lokalizacje należy:
1) usunąć plik ~/.zeusoldscratch (rm ~/.zeusoldscratch)
2) przelogować się
3) upewnić się że zmienna $SCRATCH wskazuje na nową lokalizacje (echo $SCRATCH)
4) upewnić się że w skryptach znajduje się odwołanie do nowej lokalizacji

Po wykonaniu w/w czynnosci niniejszy komunikat nie bedzie sie pojawiał
-------------------------------------------------------------------------------

------------------------------ WARNING ----------------------------------------

You are using the old scratch filesystem (/mnt/lustre/scratch/...)
New location is (/mnt/lustre/scratch2/...)

Since Nov 15 old scratch location is not supported. The filesystem is to be
decommisioned soon.

In order to switch to a new filesystem:
1) remove ~/.zeusoldscratch file
2) relogin
3) make sure that $SCRATCH variable is now pointing to a new location
4) make sure that your job scripts contain a new location (/mnt/lustre/scratch2)

--------------------------------------------------------------------------------


(Wysylanie przerwane / Submission Aborted)
qsub: submit filter returned an error code, aborting job submission.
    out

    @qsub.stubs(:submit_job_cmd).with(@record).returns(cmd)
    @ssh.stubs(:exec!).with(SSHAccessedInfrastructure::Command::cd_to_simulation_managers(cmd)).returns(output)

    assert_raises JobSubmissionFailed, output do
      @qsub.submit_job(@ssh, @record)
    end
  end

  ##
  # Queue name should be used if provided in record
  def test_prepare_job_descriptor_queue
    sm_uuid = 'sm_uuid'
    time_limit = 1000

    PlGridJob.expects(:queue_for_minutes).never

    desc = @qsub.prepare_job_descriptor('sm_uuid',
                                 'queue_name' => 'some_queue',
                                 'time_limit' => time_limit
    )

    assert_match /#PBS -q some_queue\s*\n/, desc
  end

  def test_memory_should_be_used_when_set
    desc = @qsub.prepare_job_descriptor('sm_uuid', 'memory' => '2')

    assert_match /#PBS -l mem=2gb\s*\n/, desc    
  end

  def test_memory_should_not_be_used_when_blank
    desc = @qsub.prepare_job_descriptor('sm_uuid', 'memory' => '')

    assert(/#PBS -l mem=\s*\n/ !~ desc)
  end

end