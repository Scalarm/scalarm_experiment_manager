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


  test 'Not successful registration of simulation should' do
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

    assert_response 500, response.body
  end
  test 'Not successful registration of simulation with wrong array' do
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
                 entities: [1]
             },
             format: :json
         }

    assert_response 500, response.body
  end
  test 'Not successful registration of simulation with empty array' do
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
                 entities: []
             },
             format: :json
         }

    assert_response 500, response.body
  end
  test 'Successful registration of simulation with simulation input' do
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

  test 'Failed registration of simulation with simulation input (no param id)' do
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
                                                                   id: "",
                                                                   type: "float",
                                                                   min: 0,
                                                                   max: 100
                                                               }]
                                               }]
                                }],
             format: :json
         }

    assert_response 500, response.body
  end
  test 'Failed registration of simulation with simulation input label as array' do
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
                                    label: [],
                                    entities: [{
                                                   parameters:[{
                                                                   id: "params",
                                                                   type: "float",
                                                                   min: 0,
                                                                   max: 100
                                                               }]
                                               }]
                                }],
             format: :json
         }

    assert_response 500, response.body
  end
  test 'Failed registration of simulation with simulation input more entities (no param id)' do
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
                                                                   id: "",
                                                                   type: "float",
                                                                   min: 0,
                                                                   max: 100
                                                               }]
                                               },
                                               {  parameters:[{
                                                                 id: "",
                                                                 type: "float",
                                                                 min: 0,

                                                             }]

                                               }]
                                }],
             format: :json
         }

    assert_response 500, response.body
  end
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
                                                   parameters:[{
                                                                   id: "",
                                                                   type: "float",
                                                                   min: 0,
                                                                   max: 100
                                                               }]
                                               },
                                               {  parameters:[{
                                                                  id: "",
                                                                  type: "float",
                                                                  min: 0,

                                                              }]

                                               }]
                                },{
                                    id: "category",
                                    entities: [{
                                                   id: "group",
                                                   parameters:[{
                                                                  id: "",
                                                                  type: "float",
                                                                  min: 0,
                                                                  max: 100
                                                              }]
                                              },
                                               {  parameters:[{
                                                                 id: "",
                                                                 type: "float",
                                                                 min: 0,

                                                             }]

                                               }]
                                 }],
             format: :json
         }

    assert_response 500, response.body
  end
  test 'Succesful registration of simulation with categories and entities' do
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
             simulation_input: [{"entities"=>
        [{"parameters"=>[{"id"=>"x_size", "label"=>"Image X size", "type"=>"integer", "min"=>1, "max"=>1000},
                         {"id"=>"y_size", "label"=>"Image Y size", "type"=>"integer", "min"=>1, "max"=>1000},
                         {"id"=>"black_probability", "label"=>"Blackness percentage", "type"=>"float", "min"=>0, "max"=>1},
                         {"id"=>"temp", "label"=>"Start temperature", "type"=>"integer", "min"=>0, "max"=>1000},
                         {"id"=>"iter_limit", "label"=>"Iterations limit", "type"=>"integer", "min"=>1, "max"=>1000},
                         {"id"=>"pair_swaps", "label"=>"Initial number of pair swaps", "type"=>"integer", "min"=>0, "max"=>50}]}]}],
             format: :json
         }
    assert_response 200, response.body
  end
end
