require 'minitest/autorun'
require 'test_helper'
require 'mocha/test_unit'
require 'db_helper'

class SchedulingSimulationManagersTest < ActionDispatch::IntegrationTest
  include DBHelper

  def setup
    super

    @u = ScalarmUser.new({login: 'test'})
    @u.password = "pass"
    @u.save
    @user_id = @u.id
    post login_path, username: @u.login, password: "pass"

    @exp = Experiment.new({user_id: @u.id})
    @exp.save

    @cluster = ClusterRecord.new({name: 'pro', host: 'ui.example.com', scheduler: 'slurm'})
    @cluster.save
  end

  def teardown
    super
  end

  test 'scheduling workers with qsub should create plgrid job records' do
    GridCredentials.any_instance.stubs(:invalid).returns(false)

    post schedule_simulation_managers_infrastructure_path, {
      experiment_id: @exp.id,
      infrastructure_name: 'qsub',
      job_counter: 3,
      nodes: 1,
      ppn: 1,
      time_limit: 60,
      plgrid_login: 'temp',
      plgrid_password: 'temp'
    }, { user: @user_id }

    assert_equal 3, PlGridJob.all.size
  end

  test 'scheduling workers with slurm should create job records' do
    ClusterCredentials.any_instance.stubs(:valid?).returns(true)
    InfrastructureFacade.stubs(:send_and_launch_onsite_monitoring)

    post schedule_simulation_managers_infrastructure_path, {
      experiment_id: @exp.id,
      infrastructure_name: "cluster_#{@cluster.id}",
      job_counter: 5,
      nodes: 1,
      ppn: 1,
      time_limit: 60,
      type: 'password',
      login: 'temp',
      password: 'temp',
      onsite_monitoring: false
    }, { user: @user_id }

    assert_equal 5, JobRecord.all.size
  end

end
