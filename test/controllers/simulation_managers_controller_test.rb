require 'test_helper'

# TODO - these tests do not work!
class SimulationManagersControllerTest < ActionController::TestCase
  def setup
    @user = mock 'user'
    @user_id = mock 'user_id'

    ScalarmUser.stubs(:find_by_id).with(@user_id).returns(@user)

    ApplicationController.any_instance.stubs(:authenticate)
    ApplicationController.any_instance.stubs(:start_monitoring)
    ApplicationController.any_instance.stubs(:stop_monitoring)

    SimulationManagersController.any_instance.stubs(:set_user_id)
    SimulationManagersController.any_instance.stubs(:instance_variable_get).with(:@user_id).returns(@user_id)
    SimulationManagersController.any_instance.stubs(:load_infrastructure)
  end

  def test_index
    r1 = mock 'record1' do
      expects(:to_h)
    end
    sm_records = [r1]
    SimulationManagersController.any_instance.expects(:get_all_sm_records).returns(sm_records)
    get :index
    assert_response :success, @response.body.to_s
  end
end
