require 'test_helper'
require 'db_helper'

class CreateParamsFilteringTest < ActionDispatch::IntegrationTest
  include DBHelper

  INPUT_SPECIFICATION = [
      {
          'id' => 'c',
          'label' => 'Opis funkcji',
          'entities' =>
              [
                  {
                      'id' => 'g',
                      'label' => 'Argumenty funkcji',
                      'parameters' =>
                          [
                          ]
                  }
              ]
      }
  ]
  PASSWORD = 'password'
  USER_NAME = 'user_name'

  def setup
    super
    # log in user and set sample simulation
    @user = ScalarmUser.new({login: USER_NAME})
    @user.password = PASSWORD
    @user.save
    post login_path, username: USER_NAME, password: PASSWORD
    @simulation = Simulation.new(name: 'name', description: 'description',
                                 input_parameters: {}, input_specification: INPUT_SPECIFICATION)
    @simulation.user_id = @user.id
    @simulation.save
    # mock information service
    information_service = mock do
      stubs(:get_list_of).returns([])
      stubs(:sample_public_url).returns(nil)
    end
    InformationService.stubs(:new).returns(information_service)
  end

  test 'create should filter forbidden values in params passed to experiment factory' do
    assert_difference 'Experiment.count', 1 do
      post "#{experiments_path}.json", simulation_id: @simulation.id, doe: [].to_json,
           experiment_input: INPUT_SPECIFICATION.to_json,
           bad_param: 'param'
    end

    json_response = JSON.parse(response.body)
    assert_equal 'ok', json_response['status'], "Wrong experiment creation response: #{json_response}"

    id = json_response["experiment_id"]

    experiment = Experiment.find_by_id(id)
    assert_not experiment.attributes.has_key?("bad_param"), 'Bad params should be filtered'
  end

end
