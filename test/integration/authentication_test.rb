require 'csv'
require 'minitest/autorun'
require 'mocha/test_unit'

require 'scalarm/service_core'
require 'scalarm/service_core/logger'
require 'scalarm/service_core/test_utils/authentication_test_cases'

##
# Tests authentication methods from Scalarm::ServiceCore
# Test cases are included from Scalarm::ServiceCore::TestUtils::AuthenticationTestCases
# -- see that file for details
# To pass some tests, root HTTP method ("/") is needed to accept json and return 200 if authenticated
# successfully. Root method should return:
# {status: 'ok', message: 'Welcome to Scalarm', user_id: @current_user.id.to_s }
class AuthenticationTest < ActionDispatch::IntegrationTest
  include Scalarm::ServiceCore::TestUtils::AuthenticationTestCases

  Scalarm::ServiceCore::Logger.set_logger(Rails.logger)

  def setup
    super
  end

  def teardown
    super
  end

  Scalarm::ServiceCore::TestUtils::AuthenticationTestCases.define_all_tests

end