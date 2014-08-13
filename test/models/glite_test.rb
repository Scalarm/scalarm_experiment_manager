require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'infrastructure_facades/plgrid/grid_schedulers/glite'

class GliteTest < Minitest::Test

  def setup
  end

  def teardown
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

  def test_state_waiting
    logger = stub_everything
    glite = GliteScheduler::PlGridScheduler.new(logger)
    glite.expects(:glite_state).returns('Waiting').once

    assert_equal :initializing, glite.status(Object.new, Object.new)
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

end