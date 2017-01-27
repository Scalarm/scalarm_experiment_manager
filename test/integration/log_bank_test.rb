require 'zip'

require 'test_helper'
require 'db_helper'

class LogBankControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
    @controller = Storage::LogBankController.new

    Storage::LogBankController.any_instance.stubs(:authorize_put)
    Storage::LogBankController.any_instance.stubs(:authorize_get)

    stub_authentication
    @experiment_id = '7563304ae13823b1dfa3c7ce'

    @user.save
    experiment = Experiment.new(id: @experiment_id, user_id: @user.id)
    experiment.save

    @fake_output_file = ActionDispatch::Http::UploadedFile.new({tempfile: File.new(Rails.root.join("test/fixtures/fake_output.tar.gz"))})
    @fake_stdout_file = ActionDispatch::Http::UploadedFile.new({tempfile: File.new(Rails.root.join("test/db_helper.rb"))})
  end

  def teardown
    super
  end

  test "should get status" do
    get :status
    assert_response :success
  end

  test "get_simulation_stdout_size should return correct file size" do
    SimulationOutputRecord.new(experiment_id: @experiment_id, simulation_idx: '1', file_size: 12345, type: 'stdout').save

    assert_not_nil SimulationOutputRecord.where(experiment_id: @experiment_id, simulation_idx: '1', type: 'stdout').first

    get :get_simulation_stdout_size, experiment_id: @experiment_id, simulation_id: '1'

    assert_response :success

    resp = JSON.parse(response.body)
    assert_equal 12345, resp['size']
  end

  test "put_simulation_stdout should store a file in db" do
    post :put_simulation_stdout, experiment_id: @experiment_id, simulation_id: '1', file: @fake_stdout_file
    assert_response :success

    file_record = SimulationOutputRecord.where(experiment_id:  @experiment_id, simulation_idx: '1', type: 'stdout').first

    assert_not_nil file_record
    assert_equal @fake_stdout_file.tempfile.size, file_record.file_size
    assert_equal @fake_stdout_file.tempfile.size, file_record.file_object.size
  end

  test "get_simulation_stdout should retrieve a file stored in a db" do
    post :put_simulation_stdout, experiment_id: @experiment_id, simulation_id: '1', file: @fake_stdout_file
    assert_response :success

    get :get_simulation_stdout, experiment_id: @experiment_id, simulation_id: '1'

    assert_response :success

    assert_equal File.read(@fake_stdout_file.path), response.body
  end

  test "put_simulation_output should store a file in db" do
    post :put_simulation_output, experiment_id: @experiment_id, simulation_id: '1', file: @fake_output_file
    assert_response :success

    file_record = SimulationOutputRecord.where(experiment_id:  @experiment_id, simulation_idx: '1', type: 'binary').first

    assert_not_nil file_record
    assert_equal @fake_output_file.tempfile.size, file_record.file_size
    assert_equal @fake_output_file.tempfile.size, file_record.file_object.size
  end

  test "get_simulation_output_size should return correct file size" do
    SimulationOutputRecord.new(experiment_id: @experiment_id, simulation_idx: '1', file_size: 12345, type: 'binary').save

    assert_not_nil SimulationOutputRecord.where(experiment_id: @experiment_id, simulation_idx: '1', type: 'binary').first

    get :get_simulation_output_size, experiment_id: @experiment_id, simulation_id: '1'

    assert_response :success
    resp = JSON.parse(response.body)
    assert_equal 12345, resp['size']
  end

  test "get_simulation_output should retrieve a file stored in a db" do
    post :put_simulation_output, experiment_id: @experiment_id, simulation_id: '1', file: @fake_output_file
    assert_response :success

    get :get_simulation_output, experiment_id: @experiment_id, simulation_id: '1'

    assert_response :success
    assert_equal File.read(@fake_output_file.path).force_encoding("ASCII-8BIT"), response.body.force_encoding("ASCII-8BIT")
  end

  test "get_experiment_output_size should return correct file size" do
    SimulationOutputRecord.new(experiment_id: @experiment_id, simulation_idx: '1', file_size: 1000, type: 'binary').save
    SimulationOutputRecord.new(experiment_id: @experiment_id, simulation_idx: '1', file_size: 2000, type: 'stdout').save

    assert_equal 2, SimulationOutputRecord.where(experiment_id: @experiment_id).count

    get :get_experiment_output_size, experiment_id: @experiment_id

    assert_response :success
    resp = JSON.parse(response.body)
    assert_equal 1000+2000, resp['size']
  end

  test "get_experiment_output should return a tar file with experiment results" do
    post :put_simulation_output, experiment_id: @experiment_id, simulation_id: '1', file: @fake_output_file
    assert_response :success

    post :put_simulation_stdout, experiment_id: @experiment_id, simulation_id: '1', file: @fake_stdout_file
    assert_response :success

    assert_equal 2, SimulationOutputRecord.where(experiment_id: @experiment_id).count

    get :get_experiment_output, experiment_id: @experiment_id

    assert_response :success
    file = Tempfile.new('experiment_output')
    file.write(response.body.force_encoding("UTF-8"))
    file.close

    Zip::File.open(file.path) do |zip_file|
      # Handle entries one by one
      zip_file.each do |entry|
        assert ["experiment_#{@experiment_id}/simulation_1.tar.gz", "experiment_#{@experiment_id}/simulation_1_stdout.txt"].include?(entry.name)
      end
    end

    file.unlink
  end

end
