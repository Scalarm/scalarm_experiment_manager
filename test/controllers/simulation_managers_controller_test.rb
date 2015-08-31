require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'db_helper'

class SimulationManagersControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
    stub_authentication
  end

  def teardown
    super
  end

  # For SCAL-943
  # TODO: what behaviour should be if there is only one of fields: cmd_to_execute or cmd_to_execute_code?

  test 'index with has_cmd_to_execute set to true should filter records from db with cmd to execute on PBS' do
    # given database
    PlGridJob.new(i: 1, cmd_to_execute: 'echo hello', cmd_to_execute_code: 'say_hello', scheduler_type: 'qsub', state: :error).save
    PlGridJob.new(i: 2, cmd_to_execute: 'echo hello', cmd_to_execute_code: 'say_hello', scheduler_type: 'qsub', state: :created).save
    PlGridJob.new(i: 3, scheduler_type: 'qsub', cmd_to_execute_code: '', cmd_to_execute: '', state: :error).save
    PlGridJob.new(i: 4, scheduler_type: 'qsub', state: :created).save

    # when
    get :index, infrastructure: 'qsub', has_cmd_to_execute: 'true'

    # then
    assert_response :success, response.body

    sm_records = JSON.parse(response.body)['sm_records']

    assert_equal 2, sm_records.count, "response should return 2 prepared records, but returned: #{sm_records}"

    response_is = sm_records.collect { |r| r['i'] }

    assert_includes response_is, 1, 'prepared record with i=1 is not found in response'
    assert_includes response_is, 2, 'prepared record with i=2 is not found in response'
  end

  test 'index with has_cmd_to_execute set to true should filter records from db with cmd to execute on private_machine' do
    # given database
    PrivateMachineRecord.new(i: 1, cmd_to_execute: 'echo hello', cmd_to_execute_code: 'say_hello', scheduler_type: 'qsub', state: :error).save
    PrivateMachineRecord.new(i: 2, cmd_to_execute: 'echo hello', cmd_to_execute_code: 'say_hello', scheduler_type: 'qsub', state: :created).save
    PrivateMachineRecord.new(i: 3, scheduler_type: 'qsub', cmd_to_execute_code: '', cmd_to_execute: '', state: :error).save
    PrivateMachineRecord.new(i: 4, scheduler_type: 'qsub', state: :created).save

    # when
    get :index, infrastructure: 'private_machine', has_cmd_to_execute: 'true'

    # then
    assert_response :success, response.body

    sm_records = JSON.parse(response.body)['sm_records']

    assert_equal 2, sm_records.count, "response should return 2 prepared records, but returned: #{sm_records}"

    response_is = sm_records.collect { |r| r['i'] }

    assert_includes response_is, 1, 'prepared record with i=1 is not found in response'
    assert_includes response_is, 2, 'prepared record with i=2 is not found in response'
  end

  test 'index with has_cmd_to_execute set to false should filter records from db without cmd to execute on private_machine' do
    # given database
    PrivateMachineRecord.new(i: 1, cmd_to_execute: 'echo hello', cmd_to_execute_code: 'say_hello', scheduler_type: 'qsub', state: :error).save
    PrivateMachineRecord.new(i: 2, cmd_to_execute: 'echo hello', cmd_to_execute_code: 'say_hello', scheduler_type: 'qsub', state: :created).save
    PrivateMachineRecord.new(i: 3, scheduler_type: 'qsub', cmd_to_execute_code: '', cmd_to_execute: '', state: :error).save
    PrivateMachineRecord.new(i: 4, scheduler_type: 'qsub', state: :created).save

    # when
    get :index, infrastructure: 'private_machine', has_cmd_to_execute: 'false'

    # then
    assert_response :success, response.body

    sm_records = JSON.parse(response.body)['sm_records']

    assert_equal 2, sm_records.count, "response should return 2 prepared records, but returned: #{sm_records}"

    response_is = sm_records.collect { |r| r['i'] }

    assert_includes response_is, 3, 'prepared record with i=3 is not found in response'
    assert_includes response_is, 4, 'prepared record with i=4 is not found in response'
  end

end
