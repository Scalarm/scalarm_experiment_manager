require 'test_helper'
require 'json'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructuresControllerTest < ActionController::TestCase
  tests InfrastructuresController
  # TODO: this test uses database connection

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}
    #
    # # @tmp_user_id = '1'
    #
    @tmp_user = ScalarmUser.new({login: 'test'})
    # # @tmp_user.id = @tmp_user_id
    @tmp_user.save
    @tmp_user_id = @tmp_user.id
    #
    # # ScalarmUser.stubs(:find_by_id).with(@tmp_user_id).returns(@tmp_user)
  end

  def teardown
  end

  # Helper like: "leaves = @tree.nodes(@root).filter((d) => d['type'] == 'sm-container-node')"
  # in infrastructures_tree view
  def find_sm_containers(root, results)
    if root['infrastructure_name']
      results << root
    elsif root.has_key?('children')
      root['children'].each {|child| find_sm_containers(child, results)}
    end
  end

  def test_tree
    # Prepare sm_record_hashes for every known Facade
    infrastrucutre_names = %w(qsub glite qcg pl_cloud amazon google private_machine dummy)
    infrastrucutre_names.each do |name|
      facade_class = InfrastructureFacadeFactory.get_facade_for(name).class
      facade_class.any_instance.stubs(:sm_record_hashes).with(@tmp_user_id).returns(
          (1..10).map do |i|
            {
                name: "#{name}-#{i}"
            }
          end
      )
    end

    get :list, {}, {user: @tmp_user_id}
    tree_content = nil
    assert_nothing_raised { tree_content = JSON.parse(response.body) }
    assert_kind_of Array, tree_content

    tree_root = {'name'=> 'Scalarm', 'children'=>tree_content}

    # Find nodes which will be parents to Simulation Manager nodes, like in tree view
    # AKA "sm_containers"
    container_nodes = []
    find_sm_containers(tree_root, container_nodes)
    container_nodes.each do |node|
      assert_includes infrastrucutre_names, node['infrastructure_name']
    end

    # Fetch Simulation Manager nodes for each sm_container, and check if they match
    # previously generated sm-hashes
    infrastrucutre_names.each do |infrastructure_name|
      get :simulation_manager_records, {infrastrucutre_name: infrastructure_name}, {user: @tmp_user_id}
      sm_nodes = JSON.parse(response.body)
      assert_kind_of Array, sm_nodes
      sm_nodes.each do |node|
        node['name'] =~ /^#{infrastructure_name}/
      end
    end

  end

  def test_simulation_manager_records_plgrid
    require_dependency 'infrastructure_facades/plgrid/pl_grid_facade_factory'

    count = 10
    id_values = (0..count-1).to_a

    scheduler_names = PlGridFacadeFactory.instance.provider_names

    scheduler_names.each do |sname|
      id_values.each do |i|
        hash = {user_id: @tmp_user_id, scheduler_type: sname, job_id: i.to_s}
        PlGridJob.new(hash).save
      end
    end

    scheduler_names.each do |sname|
      get :simulation_manager_records, {infrastructure_name: sname},
          {user: @tmp_user_id}

      resp_hash = JSON.parse(response.body)
      assert_equal count, resp_hash.size, response.body
      assert_equal id_values.map(&:to_s).sort, resp_hash.map {|h| h['name']}.sort, response.body
      resp_hash.map do |h|
        assert_includes h, 'scheduler_type'
        assert_equal sname, h['scheduler_type']
      end
    end

    get :simulation_manager_records, {infrastructure_name: 'plgrid', infrastructure_params: {scheduler_type: 'unknown'}},
        {user: @tmp_user_id}
    resp_hash = JSON.parse(response.body)
    assert_equal resp_hash.size, 0
  end

  def test_simulation_manager_records_invalid_name
    get :simulation_manager_records, {infrastructure_name: 'wrong_name'}, {user: @tmp_user_id}
    parsed_response = JSON.parse(response.body)

    assert_equal [], parsed_response
  end

  def test_simulation_manager_commands
    commands = %w(restart stop destroy_record)
    commands.each do |cmd|
      mock_sm = mock 'simulation_manager' do
        expects(cmd).once
      end
      InfrastructuresController.any_instance.stubs(:yield_simulation_manager).with('1', 'inf').yields(mock_sm)

      post :simulation_manager_command, {record_id: '1', infrastructure_name: 'inf', command: cmd},
          {user: @tmp_user_id}
    end
  end

  def test_remove_credentials
    InfrastructureFacadeFactory.get_registered_infrastructure_names.each do |facade_id|
      facade = InfrastructureFacadeFactory.get_facade_for(facade_id)
      facade.class.any_instance.expects(:remove_credentials).returns(nil).once
      post :remove_credentials, {infrastructure_name: facade_id, record_id: 1, type: 'secrets'},
          {user: @tmp_user_id}

      assert_equal 'ok', JSON.parse(response.body)['status'], "facade: #{facade_id}, response: #{response.body}"
    end
  end

  def test_remove_credentials_fail
    InfrastructureFacadeFactory.get_all_infrastructures.each do |facade|
      facade.class.any_instance.expects(:remove_credentials).throws(StandardError.new 'some error').once
      get :remove_credentials, {infrastructure_name: facade.short_name, record_id: 1, type: 'secrets'},
          {user: @tmp_user_id}

      assert_equal 'error', JSON.parse(response.body)['status'], "facade: #{facade.short_name}, response: #{response.body}"
    end
  end

  def test_schedule_with_invalid_creds
    require 'json'

    params = {
        'experiment_id'=> 'e1',
        'infrastructure_name'=> 'inf_name',
        'job_counter'=>'3'
    }
    user_id = @tmp_user_id
    experiment = stub_everything do
      stubs(:shared_with).returns([])
      stubs(:user_id).returns(user_id)
    end
    Experiment.stubs(:find_by_id).with('e1').returns(experiment)

    # facade = stub_everything 'facade'
    facade = stub_everything do
      expects(:start_simulation_managers)
        .with(user_id, 3, 'e1', params.merge('controller' => 'infrastructures', 'action' => 'schedule_simulation_managers'))
        .raises(InfrastructureErrors::InvalidCredentialsError.new).once
    end

    InfrastructureFacadeFactory.expects(:get_facade_for).with('inf_name').returns(facade)

    post :schedule_simulation_managers, params, {user: @tmp_user_id}

    resp_hash = JSON.parse(response.body)

    assert_equal 'error', resp_hash['status']
    assert_equal 'invalid-credentials', resp_hash['error_code']
  end

  def test_schedule_incomplete
    params = {
        'experiment_id'=> 'e1',
        'infrastructure_name'=> 'inf_name',
        'job_kounter!'=>'3'
    }

    post :schedule_simulation_managers, params, {user: @tmp_user_id}

    resp_hash = JSON.parse(response.body)

    assert_equal 'error', resp_hash['status']
    assert_equal 'missing-parameters', resp_hash['error_code']
  end

  def test_schedule_simulation_managers
    require 'json'

    u1 = ScalarmUser.new({_id: 'u1', login: '1'})
    ScalarmUser.stubs(:find_by_id).returns(u1)

    e1 = stub_everything 'exp1' do
      stubs(:user_id).returns('u1')
      stubs(:shared_with).returns([])
    end
    Experiment.stubs(:find_by_id).with('e1').returns(e1)

    params = {
        'experiment_id'=> 'e1',
        'infrastructure_name'=> 'inf_name',
        'job_counter'=>'3'
    }
    facade = stub_everything 'facade'
    facade.expects(:start_simulation_managers)
    .with('u1', 3, 'e1', params.merge('controller' => 'infrastructures', 'action' => 'schedule_simulation_managers'))
    .returns(['ok', 'good']).once

    InfrastructureFacadeFactory.expects(:get_facade_for).with('inf_name').returns(facade)

    get :schedule_simulation_managers, params, {user: 'u1'}

    resp_hash = JSON.parse(response.body)

    assert_equal 'ok', resp_hash['status'], response.body
  end

  def test_schedule_for_foreign_experiment
    u1 = ScalarmUser.new({_id: 'u1', login: '1'})
    u2 = ScalarmUser.new({_id: 'u2', login: '2'})

    ScalarmUser.stubs(:find_by_id).with('u1').returns(u1)
    ScalarmUser.stubs(:find_by_id).with('u2').returns(u2)

    u1 = stub_everything 'user1'
    u2 = stub_everything 'user2'

    e1 = stub_everything 'exp1' do
      stubs(:id).returns('e1')
      stubs(:user_id).returns('u1')
      stubs(:shared_with).returns([])
    end

    e2 = stub_everything 'exp2' do
      stubs(:id).returns('e2')
      stubs(:user_id).returns('u2')
      stubs(:shared_with).returns([])
    end

    Experiment.stubs(:find_by_id).returns(e1)
    Experiment.stubs(:find_by_id).returns(e2)

    facade = stub_everything 'infrastructure' do
      expects(:start_simulation_managers).never
    end

    InfrastructureFacadeFactory.stubs(:get_facade_for).with('inf_test').returns(facade)

    post :schedule_simulation_managers, {
        infrastructure_name: 'inf_test',
        job_counter: 1,
        experiment_id: 'e2'
    }, {user: 'u1'}

    resp_hash = JSON.parse(response.body)

    assert_equal 'error', resp_hash['status'], response.body
    assert_equal 'foreign-experiment', resp_hash['error_code']
  end

  def test_schedule_for_shared_experiment
    u1 = ScalarmUser.new({_id: 'u1', login: '1'})
    u2 = ScalarmUser.new({_id: 'u2', login: '2'})

    ScalarmUser.stubs(:find_by_id).with('u1').returns(u1)
    ScalarmUser.stubs(:find_by_id).with('u2').returns(u2)

    u1 = stub_everything 'user1'
    u2 = stub_everything 'user2'

    e1 = stub_everything 'exp1' do
      stubs(:id).returns('e1')
      stubs(:user_id).returns('u1')
      stubs(:shared_with).returns([])
    end

    e2 = stub_everything 'exp2' do
      stubs(:id).returns('e2')
      stubs(:user_id).returns('u2')
      stubs(:shared_with).returns(['u1'])
    end

    Experiment.stubs(:find_by_id).returns(e1)
    Experiment.stubs(:find_by_id).returns(e2)

    facade = stub_everything 'infrastructure' do
      expects(:start_simulation_managers).returns(['ok', 'good']).once
    end

    InfrastructureFacadeFactory.stubs(:get_facade_for).with('inf_test').returns(facade)

    post :schedule_simulation_managers, {
        infrastructure_name: 'inf_test',
        job_counter: 1,
        experiment_id: 'e2'
    }, {user: 'u1'}

    resp_hash = JSON.parse(response.body)

    assert_equal 'ok', resp_hash['status'], response.body
  end

end
