require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/grid_schedulers/glite'

class GliteTest < Minitest::Test

  def setup
    @logger = mock 'logger'
    @glite = GliteScheduler::PlGridScheduler.new(@logger)
  end

  def test_parse_job_id
    output = <<-eos

Connecting to the service https://kashyyyk.wcss.pl:7443/glite_wms_wmproxy_server


====================== glite-wms-job-submit Success ======================

The job has been successfully submitted to the WMProxy
Your job identifier is:

https://lb02.grid.cyf-kr.edu.pl:9000/VdIE_cHwTo8qWRZFa69R5Q

==========================================================================
    eos

    assert_equal 'https://lb02.grid.cyf-kr.edu.pl:9000/VdIE_cHwTo8qWRZFa69R5Q', GliteScheduler::PlGridScheduler.parse_job_id(output)
  end

  def test_glite_state
    job_info = mock 'job_info'
    logger = mock 'logger'
    ssh = mock 'ssh'
    job_id = mock 'job_id'

    glite = GliteScheduler::PlGridScheduler.new(logger)
    glite.stubs(:get_job_info).with(ssh, job_id).returns(job_info)

    GliteScheduler::PlGridScheduler.expects(:parse_job_status).with(job_info).once

    glite.glite_state(ssh, job_id)
  end

  def test_parse_job_status_waiting
    ssh = mock('ssh')
    job_id = mock 'job_id'
    job = mock('job') {
      stubs(:job_id).returns(job_id)
    }
    @glite.stubs(:glite_state).returns('Waiting').once

    assert_equal :initializing, @glite.status(ssh, job)
  end

  def test_parse_job_status_scheduled
    ssh = mock('ssh')
    job_id = mock 'job_id'
    job = mock('job') {
      stubs(:job_id).returns(job_id)
    }
    @glite.stubs(:glite_state).returns('Scheduled').once

    assert_equal :initializing, @glite.status(ssh, job)
  end

  def test_parse_status
    output = <<-eos

======================= glite-wms-job-status Success =====================
BOOKKEEPING INFORMATION:

Status info for the Job : https://lb02.grid.cyf-kr.edu.pl:9000/gPiJNrnEunrtKg3S-z6OPQ
Current Status:     Scheduled
Status Reason:      unavailable
Destination:        dwarf.wcss.wroc.pl:8443/cream-pbs-plgrid
Submitted:          Thu Apr 17 20:59:31 2014 CEST
==========================================================================

    eos

    assert_equal 'Scheduled', GliteScheduler::PlGridScheduler.parse_job_status(output)

  end

  def test_parse_done_exit_code_status
    output = <<-eos

======================= glite-wms-job-status Success =====================
BOOKKEEPING INFORMATION:

Status info for the Job : https://lb02.grid.cyf-kr.edu.pl:9000/jwoxZ_0jDzEp3NI9cYolyg
Current Status:     Done(Exit Code !=0)
Exit code:          127
Status Reason:      Job Terminated Successfully
Destination:        ce9.grid.icm.edu.pl:8443/cream-pbs-plgrid
Submitted:          Wed Aug 13 15:12:03 2014 CEST
==========================================================================

    eos

    assert_equal 'Done(Exit Code !=0)', GliteScheduler::PlGridScheduler.parse_job_status(output)

  end

  def test_map_done_to_deactivated
    assert_equal :deactivated, GliteScheduler::PlGridScheduler.map_status('Done(Exit Code !=0)')
    assert_equal :deactivated, GliteScheduler::PlGridScheduler.map_status('Done(Success)')
  end

  def test_map_running_to_running
    assert_equal :running, GliteScheduler::PlGridScheduler.map_status('Running')
  end

  def test_map_unknown_to_nil
    assert_equal nil, GliteScheduler::PlGridScheduler.map_status('something')
  end

  def test_parse_get_output
    output = <<-eos

Connecting to the service https://kashyyyk.wcss.pl:7443/glite_wms_wmproxy_server


================================================================================

                        JOB GET OUTPUT OUTCOME

Output sandbox files for the job:
https://lb02.grid.cyf-kr.edu.pl:9000/0zW7VCkww40HDY3t-gcV2A
have been successfully retrieved and stored in the directory:
/people/plgjliput/plgjliput_0zW7VCkww40HDY3t-gcV2A

================================================================================

    eos

    assert_equal '/people/plgjliput/plgjliput_0zW7VCkww40HDY3t-gcV2A', GliteScheduler::PlGridScheduler.parse_get_output(output)
  end

  def test_use_ce
    host_key = 'dwarf.wcss.wroc.pl'
    host_value = GliteScheduler::PlGridScheduler.host_addresses[host_key]

    logger = stub_everything
    glite = GliteScheduler::PlGridScheduler.new(logger)

    descriptor = glite.prepare_job_descriptor('sm_uuid', {'plgrid_host'=>host_key})

    assert_match /other.GlueCEUniqueID == \"#{host_value}\"/, descriptor
  end

  def test_use_default_ce
    host_value = GliteScheduler::PlGridScheduler.host_addresses[GliteScheduler::PlGridScheduler.default_host]

    logger = stub_everything
    glite = GliteScheduler::PlGridScheduler.new(logger)

    descriptor = glite.prepare_job_descriptor('sm_uuid', {})

    assert_match /other.GlueCEUniqueID == \"#{host_value}\"/, descriptor
  end

  def test_get_log
    ssh = mock 'ssh'
    job = mock 'job'
    job_id = mock 'job_id'
    job.stubs(:job_id).returns(job_id)
    num_lines = 25
    glite_stdout_path = mock 'glite_stdout_path'
    tail_command = mock 'tail_command'
    out_log = 'stdout_log'
    status_out = 'status_out'
    @glite.stubs(:get_glite_output_to_file).with(ssh, job).returns(glite_stdout_path)
    @glite.stubs(:tail).with(glite_stdout_path, num_lines).returns(tail_command)
    ssh.stubs(:exec!).with(tail_command).returns(out_log)
    @glite.stubs(:get_job_info).with(ssh, job_id).returns(status_out)

    t = @glite.get_log(ssh, job)

    r = /--- gLite info ---.*?(\w+).*?--- Simulation Manager log ---.*?(\w+).*?/m
    assert_match r, t

    assert_equal status_out, r.match(t)[1]
    assert_equal out_log, r.match(t)[2]
  end

end