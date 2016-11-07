require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'db_helper'

class SimulationsControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super
    stub_authentication
  end

  def teardown
    super
  end

  def prepare_request_content(simulation_input)

    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )

    post_content =  {
        simulation_name: 'simulation_one',
        simulation_description: 'Just testing',
        simulation_binaries: binaries,
        executor: '',
        simulation_input: simulation_input,
        format: :json
    }

  end

  ## bad format - no array of hash in category
  test 'Failed registration of simulation with wrong type' do

    simulation_input = { entities: 1 }

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  ## entity value must be hash
  test 'Failed registration of simulation with wrong array value' do

    simulation_input =  [{ entities: [1] }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation with wrong array value in entities hash' do

    simulation_input =  [{
                             entities: [
                               {}
                             ]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation with wrong value for parameters' do
    simulation_input = [{
                            entities: [
                                {
                                    parameters: {}
                                }
                            ]
                        }]
    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  ## Simulation input lacks of id for 1. category, ids for parameters, range of values for parameters
  test 'Failed registration of simulation with categories and entities' do

    simulation_input = [{
                           entities: [{
                                          label: [],
                                          parameters:[{
                                                          id: "",
                                                          type: "integer",
                                                          max: 100.765
                                                      }]
                                      },
                                      {  parameters:[{
                                                         id: "",
                                                         type: "float",
                                                         min: 0

                                                     }]

                                      }]
                       },{
                           id: "category",
                           entities: [{
                                          id: "group",
                                          parameters:[{
                                                          id: "",
                                                          type: "string",
                                                          min: 0,
                                                          max: 100
                                                      }]
                                      },
                                      {  parameters:[{
                                                         id: "",
                                                         type: "alasf",
                                                         min: 0,

                                                     }]

                                      }]
                       }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  ## single param, entity and category - in this case id required only for parameter
  test 'Successful registration of simulation with simulation input ' do

    simulation_input =  [{

                           entities: [{
                                          parameters:[{
                                                          id: "param1",
                                                          type: "float",
                                                          min: 0.5,
                                                          max: -100
                                                      }]
                                      }]
                       }]

    post :create, prepare_request_content(simulation_input)
    assert_response 200, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 200, response.body
  end

  test 'Failed registration of simulation - type: integer but value is float ' do

    simulation_input =  [{

                             entities: [{
                                            parameters:[{
                                                            id: "param1",
                                                            type: "integer",
                                                            min: 0.5,
                                                            max: -100
                                                        }]
                                        }]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation - allowed_values is required' do

    simulation_input =  [{

                             entities: [{
                                            parameters:[{
                                                            id: "param1",
                                                            type: "string"
                                                        }]
                                        }]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation - allowed_values cannot be empty array' do

    simulation_input =  [{

                             entities: [{
                                            parameters:[{
                                                            id: "param1",
                                                            type: "string",
                                                            allowed_values: []
                                                        }]
                                        }]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation - allowed_values should contain only strings' do

    simulation_input =  [{

                             entities: [{
                                            parameters:[{
                                                            id: "param1",
                                                            type: "string",
                                                            allowed_values: ['a', 1, 2]
                                                        }]
                                        }]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation - allowed_values should be an array' do

    simulation_input =  [{

                             entities: [{
                                            parameters:[{
                                                            id: "param1",
                                                            type: "string",
                                                            allowed_values: 'x'
                                                        }]
                                        }]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  test 'Failed registration of simulation - empty paramaters hash ' do

    simulation_input =  [{

                             entities: [{
                                            parameters:[{

                                                        }]
                                        }]
                         }]

    post :create, prepare_request_content(simulation_input)
    assert_response 412, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 412, response.body
  end

  # Tests registration of simulation without parameters and without executor name
  test 'Successful registration of simulation should return HTTP code 200' do
    simulation_input = [{
                           entities: [
                               {
                                   parameters: []
                               }
                           ]
                       }]
    post :create, prepare_request_content(simulation_input)
    assert_response :success, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response :success, response.body
  end

  ## Complex json with 2 categories with 2 entities with 1 parameter each.
  ## Testing various type of parameters, values with optional label, different ranges
  test 'Successful registration of simulation with categories and entities' do

    simulation_input = [{
                           id: "category1",
                           entities: [{
                                          id: "entity1",
                                          parameters:[{
                                                          id: "abc1",
                                                          type: "integer",
                                                          min: -10,
                                                          max: 100
                                                      }]
                                      },
                                      {   id: "entity2",
                                          parameters:[{
                                                          id: "abc2",
                                                          label: "new_param",
                                                          type: "float",
                                                          min: -8.5,
                                                          max: 100.5
                                                      }]

                                      }]
                       },{
                           id: "category2",
                           entities: [{
                                          id: "group",
                                          parameters:[{
                                                          id: "abc3",
                                                          type: "string",
                                                          allowed_values: ["Ala", "ma"]
                                                      }]
                                      },
                                      {   id: "group2",
                                          label: "Grupa testowa",
                                          parameters:[{
                                                          id: "abc4",
                                                          type: "float",
                                                          min: -40.4,
                                                          max: 100
                                                      }]

                                      }]
                       }]

    post :create, prepare_request_content(simulation_input)
    assert_response 200, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 200, response.body
  end

  ## Testing labels for various type of parameters and values
  test 'Successful registration of simulation with label categories and entities as json' do

    simulation_input = [{
                            id: "category1",
                            label: "new label",
                            entities: [{
                                           id: "entity1",
                                           label: "another new label",
                                           parameters:[{
                                                           id: "abc1",
                                                           type: "integer",
                                                           min: -10,
                                                           max: 100
                                                       }]
                                       },
                                       {   id: "entity2",
                                           label: "entity label",
                                           parameters:[{
                                                           id: "abc2",
                                                           label: "new_param",
                                                           type: "float",
                                                           min: -8.5,
                                                           max: 100.5
                                                       }]

                                       }]
                        },{
                            id: "category2",
                            label: "oooooo new label",
                            entities: [{
                                           id: "group",
                                           label: "lets see - label",
                                           parameters:[{
                                                           id: "abc3",
                                                           type: "string",
                                                           allowed_values: ["Ala", "foo"]
                                                       }]
                                       },
                                       {   id: "group2",
                                           label: "Grupa testowa",
                                           parameters:[{
                                                           id: "abc4",
                                                           label: "end lab",
                                                           type: "float",
                                                           min: -40.4,
                                                           max: 100
                                                       }]

                                       }]
                        }]

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 200, response.body

    post :create, prepare_request_content(simulation_input.to_json)
    assert_response 200, response.body
  end

  test 'GET registration should display a simulation scenario registration form' do
    get :registration

    assert_response :success

    assert_select '#simulation_name'
    assert_select '#simulation_description'
    assert_select '#input-definition'
    assert_select '#simulation-files'
  end

end
