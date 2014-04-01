require 'test_helper'
require 'json'

class SessionsControllerTest < ActionController::TestCase
  tests InfrastructuresController

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}

    tmp_user = ScalarmUser.new({'login' => 'tmp_login'})
    tmp_user.save
  end

  def teardown
  end

  def test_plgrid_sms
    tmp_user_id = ScalarmUser.all[0].id
    count = 10
    id_values = (0..count-1).to_a

    scheduler_names = PlGridFacade.scheduler_facade_classes.keys

    scheduler_names.each do |sname|
      id_values.each do |i|
        PlGridJob.new('user_id'=>tmp_user_id, 'scheduler_type'=>sname.to_s,
                      'job_id'=>i.to_s).save
      end
    end

    scheduler_names.each do |sname|
      get :sm_nodes, {name: sname}, {user: tmp_user_id}

      resp_hash = JSON.parse(response.body)
      assert_equal resp_hash.size, count
      assert_equal resp_hash.map {|h| h['name']}.sort, id_values.map(&:to_s).sort
    end

    get :sm_nodes, {name: 'invalid_name'}, {user: tmp_user_id}
    resp_hash = JSON.parse(response.body)
    assert_equal resp_hash.size, 0
  end

end
