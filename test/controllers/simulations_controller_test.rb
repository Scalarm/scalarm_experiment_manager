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


  ## bad format - no array of hash in category
  test 'Failed registration of simulation with wrong type' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )

    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: {
                 entities: 1
             },
             format: :json
         }

    assert_response 412, response.body
  end

  ## entity value must be hash
  test 'Failed registration of simulation with wrong array value' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )

    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: [{
                 entities: [1]
             }],
             format: :json
         }

    assert_response 412, response.body
  end

  ## Simulation input lacks of id for 1. category, ids for parameters, range of values for parameters
  test 'Failed registration of simulation with categories and entities' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )
    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: [{
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
                                 }],
             format: :json
         }

    assert_response 412, response.body
  end

  ## single param, entity and category - in this case id required only for parameter
  test 'Successful registration of simulation with simulation input ' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )

    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: [{

                                    entities: [{
                                                   parameters:[{
                                                                   id: "param1",
                                                                   type: "float",
                                                                   min: 0.5,
                                                                   max: -100
                                                               }]
                                               }]
                                }],
             format: :json
         }

    assert_response 200, response.body
  end


  # Tests registration of simulation without parameters and without executor name
  test 'successful registration of simulation should return HTTP code 200' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )

    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: [{
                                    entities: [
                                        {
                                            parameters: []
                                        }
                                    ]
                                }],
             format: :json
         }

    assert_response :success, response.body
  end

  ## Complex json with 2 categories with 2 entities with 1 parameter each.
  ## Testing various type of parameters, values with optional label, different ranges
  test 'Successful registration of simulation with categories and entities' do
    binaries = Rack::Test::UploadedFile.new(
        Rails.root.join('test', 'fixtures', 'files', 'simulation_binaries.zip'),
        'application/zip'
    )
    post :create,
         {
             simulation_name: 'simulation_one',
             simulation_description: 'Just testing',
             simulation_binaries: binaries,
             executor: '',
             simulation_input: [{
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
                                                                   allowed_values: "Ala"
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
                                }],
             format: :json
         }

    assert_response 200, response.body
  end

end
