require 'test_helper'
require 'db_helper'

require 'zip'

class ClusterFacadeIntegrationTest < ActiveSupport::TestCase
  include DBHelper

  def setup
    super

    @sm_record = mock()
    @sm_record.stubs(:sm_uuid).returns('sm_uuid')

    @user = ScalarmUser.new(login: 'user')
    @user.save

    @user2= ScalarmUser.new(login: 'user2')
    @user2.save

    @slurm = SlurmScheduler.new

    @cluster_record = ClusterRecord.new(name: "My cluster", scheduler: "slurm", host: "whatever.com", created_by: @user.id, plgrid: true)
    @cluster_record.save

    @facade = ClusterFacade.new(@cluster_record, @slurm)

    @experiment = Experiment.new({})
    @experiment.save
  end

  def teardown
    super
  end

  test 'query_simulation_manager_records should return an array of JobRecords for clusters user and experiment' do
    job1 = JobRecord.new(infrastructure_type: 'clusters', user_id: @user.id, experiment_id: @experiment.id)
    job1.save
    job2 = JobRecord.new(infrastructure_type: 'clusters', user_id: @user.id, experiment_id: @experiment.id)
    job2.save
    JobRecord.new(infrastructure_type: 'private_machines', user_id: @user.id, experiment_id: @experiment.id).save
    JobRecord.new(infrastructure_type: 'clusters', user_id: @user2.id, experiment_id: @experiment.id).save

    jobs = @facade.query_simulation_manager_records(@user.id, @experiment.id, {})

    assert_equal 2, jobs.size
    assert_equal job1.id, jobs[0].id
    assert_equal job2.id, jobs[1].id
  end

  test '_get_sm_records should return an array of JobRecords for specified criteria' do
    job1 = JobRecord.new(infrastructure_type: 'clusters', infrastructure_identifier: "cluster_#{@cluster_record.id}", user_id: @user.id, experiment_id: @experiment.id)
    job1.save
    job2 = JobRecord.new(infrastructure_type: 'clusters', infrastructure_identifier: "cluster_#{@cluster_record.id}", user_id: @user.id, experiment_id: @experiment.id)
    job2.save
    JobRecord.new(infrastructure_type: 'private_machines', user_id: @user.id, experiment_id: @experiment.id).save
    JobRecord.new(infrastructure_type: 'clusters', infrastructure_identifier: "cluster_#{@cluster_record.id}", user_id: @user2.id, experiment_id: @experiment.id).save

    jobs = @facade._get_sm_records({user_id: @user.id, experiment_id: @experiment.id})

    assert_equal 2, jobs.size
    assert_equal job1.id, jobs[0].id
    assert_equal job2.id, jobs[1].id
  end

  test 'other_params_for_booster should return a map with scheduler and a false flag for not valid credentials' do
    params = @facade.other_params_for_booster(@user.id)

    assert_equal 'slurm', params[:scheduler]
    assert_equal false, params[:user_has_valid_credentials]
  end

  test 'other_params_for_booster should return a map with scheduler and a set flag for valid plgrid credentials' do
    ScalarmUser.any_instance.stubs(:valid_plgrid_credentials).with('whatever.com').returns('something_not_false')

    params = @facade.other_params_for_booster(@user.id)

    assert_equal 'slurm', params[:scheduler]
    assert_equal true, params[:user_has_valid_credentials]
  end

  test 'other_params_for_booster should return a map with scheduler and a set flag for valid cluster credentials' do
    ClusterCredentials.new(owner_id: @user.id, cluster_id: @cluster_record.id, invalid: false).save
    ScalarmUser.any_instance.stubs(:valid_plgrid_credentials).with('whatever.com').returns(nil)

    params = @facade.other_params_for_booster(@user.id)

    assert_equal 'slurm', params[:scheduler]
    assert_equal true, params[:user_has_valid_credentials]
  end

  test 'simulation_manager_code should return path to existing zip file with code files' do
    @sm_record.stubs(:experiment_id).returns(@experiment.id)
    @sm_record.stubs(:start_at).returns(Time.now.to_s)
    @sm_record.stubs(:to_h).returns({})

    zip_path = @facade.simulation_manager_code(@sm_record)

    assert File.exist?(zip_path)

    files_in_zip = []

    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        files_in_zip << entry.name.split('/').last
      end
    end

    assert files_in_zip.include?('scalarm_job_sm_uuid.sh')
    assert files_in_zip.include?('scalarm_simulation_manager_sm_uuid.zip')
    assert files_in_zip.include?('scalarm_slurm_job_sm_uuid.sh')

    File.delete(zip_path)
  end

  test 'simulation_manager_code with block should yield a path to a zip file with code files' do
    @sm_record.stubs(:experiment_id).returns(@experiment.id)
    @sm_record.stubs(:start_at).returns(Time.now.to_s)
    @sm_record.stubs(:to_h).returns({})

    path = nil

    @facade.simulation_manager_code(@sm_record) do |zip_path|
      path = zip_path

      assert File.exist?(zip_path)

      files_in_zip = []

      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          files_in_zip << entry.name.split('/').last
        end
      end

      assert files_in_zip.include?('scalarm_job_sm_uuid.sh')
      assert files_in_zip.include?('scalarm_simulation_manager_sm_uuid.zip')
      assert files_in_zip.include?('scalarm_slurm_job_sm_uuid.sh')
    end


    assert (not File.exist?(path))
  end

  test 'load_or_create_credentials should return ClusterCredentials with GridCredentials attributes set' do
    plgrid_creds = mock()
    plgrid_creds.stubs(:login).returns('plguser')
    plgrid_creds.stubs(:secret_proxy).returns('proxy')
    ScalarmUser.any_instance.stubs(:valid_plgrid_credentials).with('whatever.com').returns(plgrid_creds)

    credentials = @facade.load_or_create_credentials(@user.id, @cluster_record.id, {})

    assert_not_nil credentials
    assert_not_nil credentials.host
    assert_not_nil credentials.login
    assert_not_nil credentials.secret_proxy
  end

  test 'load_or_create_credentials should create ClusterCredentials with provided username and password' do
    ScalarmUser.any_instance.stubs(:valid_plgrid_credentials).with('whatever.com').returns(nil)
    params = { type: 'password', login: 'user', password: 'pass' }

    credentials = @facade.load_or_create_credentials(@user.id, @cluster_record.id, params)

    assert_not_nil credentials
    assert_equal @cluster_record.id, credentials.cluster_id
    assert_equal 'user', credentials.login
    assert_equal 'pass', credentials.secret_password
  end

  test 'load_or_create_credentials should create ClusterCredentials with provided username and privkey' do
    ScalarmUser.any_instance.stubs(:valid_plgrid_credentials).with('whatever.com').returns(nil)
    params = { type: 'privkey', login: 'user', privkey: 'key' }

    credentials = @facade.load_or_create_credentials(@user.id, @cluster_record.id, params)

    assert_not_nil credentials
    assert_equal @cluster_record.id, credentials.cluster_id
    assert_equal 'user', credentials.login
    assert_equal 'key', credentials.secret_privkey
  end

  test 'load_or_create_credentials should raise error when no ClusterCredentials is found' do
    ScalarmUser.any_instance.stubs(:valid_plgrid_credentials).with('whatever.com').returns(nil)

    assert_raise(InfrastructureErrors::NoCredentialsError) do
      @facade.load_or_create_credentials(@user.id, @cluster_record.id, {})
    end
  end


end
