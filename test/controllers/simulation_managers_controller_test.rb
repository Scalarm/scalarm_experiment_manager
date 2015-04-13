require 'test_helper'
require 'db_helper'

# TODO - these tests do not work!
class SimulationManagersControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super

    @u = ScalarmUser.new(login: 'a')
    @u.password = 'b'
    @u.save

    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('a', 'b')
    request.env['ACCEPT'] = 'application/json'
  end

  def test_get_states_not
    dr1 = DummyRecord.new(user_id: @u.id)
    dr1.save

    dr1.set_state(:initializing)
    assert_equal :initializing, dr1.state

    get :index, states_not: ['initializing'].to_json
    body = JSON.parse(response.body)
    records = body['sm_records']

    assert_equal 'ok', body['status']
    assert_equal 0, records.count, records
  end

end
