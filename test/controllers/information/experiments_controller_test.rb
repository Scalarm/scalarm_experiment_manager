require 'test_helper'
require 'db_helper'

class Information::ExperimentsControllerTest < ActionController::TestCase
  include DBHelper

  add_test_get_list
  add_test_register_address
  add_test_register_address_unauthorized
  add_test_deregister_address
end
