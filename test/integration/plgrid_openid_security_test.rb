require 'test_helper'
require 'db_helper'

require 'openid_providers/openid_utils'

class MongoActiveRecordDBTest < ActiveSupport::TestCase
  include DBHelper

  def setup
    super
  end

  def teardown
    super
  end

  test 'get user with nil dn should return nil not first user from db' do
    user = ScalarmUser.new(login: 'one')
    user.save
    got_user = OpenIDUtils::get_user_with(dn: nil)

    refute_empty ScalarmUser.all
    assert_nil got_user
  end

end