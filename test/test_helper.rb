ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

require 'scalarm/service_core/test_utils/test_helper_extensions'

require 'mocha/mini_test'

require 'capybara/rails'
require 'capybara/minitest'
require 'capybara/poltergeist'

class ActiveSupport::TestCase
  include Scalarm::ServiceCore::TestUtils::TestHelperExtensions
  # Make the Capybara DSL available in all integration tests
  include Capybara::DSL
  # Make `assert_*` methods behave like Minitest assertions
  include Capybara::Minitest::Assertions

  Capybara.javascript_driver = :poltergeist

  #ActiveRecord::Migration.check_pending!

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  #fixtures :all

  # Add more helper methods to be used by all tests here...
  # Reset sessions and driver between tests
  # Use super wherever this method is redefined in your individual test classes

  def teardown
    Capybara.current_driver = nil
  end

  def use_custom_controller(controller, &block)
    old_controller = self.class.controller_class
    begin
      self.class.controller_class = controller
      yield
    ensure
      self.class.controller_class = old_controller
    end
  end

  # information service utils
  def authorize_request(request)
    user = Rails.application.secrets.information_service_user
    pw = Rails.application.secrets.information_service_pass
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user,pw)
  end

  def clear_authorization(request)
    request.env['HTTP_AUTHORIZATION'] = nil
  end

  def self.add_test_get_list
    define_method 'test_get_list' do
      get :list
      assert_response :success
    end
  end

  def self.add_test_register_address
    define_method 'test_register_address' do
      authorize_request(request)
      post :register, address: 'some_address'
      assert_response :success
      assert_equal 'ok', JSON.parse(response.body)['status']

      get :list
      assert_response :success
      assert_includes JSON.parse(response.body), 'some_address'
    end
  end

  def self.add_test_register_address_unauthorized
    define_method 'test_register_address_unauthorized' do
      authorize_request(request)
      get :list
      assert_response :success
      assert_not_includes JSON.parse(response.body), 'some_address'

      clear_authorization(request)
      post :register, address: 'some_address'
      assert_response 401
      authorize_request(request)
    end
  end

  def self.add_test_deregister_address
    define_method 'test_deregister_address' do
      authorize_request(request)
      post :register, address: 'some'
      assert_response :success

      get :list
      assert_response :success
      assert_includes JSON.parse(response.body), 'some'

      post :deregister, address: 'some'
      assert_response :success

      get :list
      assert_response :success
      assert_not_includes JSON.parse(response.body), 'some'
    end
  end

end

class MockCollection
  attr_accessor :records

  def initialize(records)
    @records = records
  end

  def <<(attributes)
    @records << attributes
  end

  def find(attributes)
    records.select do |r|
      attributes.all? {|key, value| r[key] == value}
    end
  end
end

class MockRecord
  require 'set'
  @@collection = MockCollection.new(Set.new)


  attr_reader :attributes

  def initialize(attributes)
    @attributes = attributes
  end

  def save
    @@collection << @attributes
  end

  def self.find_all_by_query(attributes)
    @@collection.find(attributes).map {|attr| MockRecord.new(attr)}
  end

  def self.collection
    @@collection
  end
end
