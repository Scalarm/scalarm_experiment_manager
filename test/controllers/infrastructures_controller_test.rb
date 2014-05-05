require 'test_helper'
require 'json'
require 'infrastructure_facades/tree_utils'
require 'infrastructure_facades/infrastructure_errors'

class InfrastructuresControllerTest < ActionController::TestCase
  tests InfrastructuresController

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_test').collections.each{|coll| coll.drop}

    @tmp_user = ScalarmUser.new({login: 'test'})
    @tmp_user.save
    @tmp_user_id = @tmp_user.id

    ScalarmUser.stubs(:find_by_id).with(@tmp_user_id).returns(@tmp_user)
  end

  def teardown
  end

  # Helper like: "leaves = @tree.nodes(@root).filter((d) => d['type'] == 'sm-container-node')"
  # in infrastructures_tree view
  def find_sm_containers(root, results)
    if root['type'] == TreeUtils::TREE_SM_CONTAINER
      results << root
    elsif root.has_key?('children')
      root['children'].each {|child| find_sm_containers(child, results)}
    end
  end

  def test_tree
    # Prepare sm_record_hashes for every known Facade
    infrastrucutre_names = %w(plgrid pl_cloud amazon private_machine)
    infrastrucutre_names.each do |name|
      facade_class = InfrastructureFacade.get_facade_for(name).class
      facade_class.any_instance.stubs(:sm_record_hashes).with(@tmp_user_id).returns(
          (1..10).map do |i|
            {
                name: "#{name}-#{i}"
            }
          end
      )
    end

    get :tree, {}, {user: @tmp_user_id}
    tree_root = nil
    assert_nothing_raised { tree_root = JSON.parse(response.body) }
    assert_kind_of Hash, tree_root

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
    count = 10
    id_values = (0..count-1).to_a

    scheduler_names = PlGridFacade.scheduler_facade_classes.keys.map &:to_s

    scheduler_names.each do |sname|
      id_values.each do |i|
        hash = {user_id: @tmp_user_id, scheduler_type: sname, job_id: i.to_s}
        PlGridJob.new(hash).save
      end
    end

    scheduler_names.each do |sname|
      get :simulation_manager_records, {infrastructure_name: 'plgrid', infrastructure_params: {scheduler_type: sname}},
          {user: @tmp_user_id}

      resp_hash = JSON.parse(response.body)
      assert_equal count, resp_hash.size
      assert_equal id_values.map(&:to_s).sort, resp_hash.map {|h| h['name']}.sort
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
    commands = %w(restart stop)
    commands.each do |cmd|
      mock_sm = Object
      mock_sm.expects(cmd).once
      InfrastructuresController.any_instance.stubs(:get_simulation_manager).with('1', 'inf').returns(mock_sm)

      post :simulation_manager_command, {record_id: '1', infrastructure_name: 'inf', command: cmd},
          {user: @tmp_user_id}
    end
  end

  def test_remove_credentials
    InfrastructureFacade.get_registered_infrastructures.each do |facade_id, info|
      info[:facade].class.any_instance.expects(:remove_credentials).returns(nil).once
      get :remove_credentials, {infrastructure_name: facade_id, record_id: 1, type: 'secrets'},
          {user: @tmp_user_id}

      assert_equal 'ok', JSON.parse(response.body)['status'], "facade: #{facade_id}, response: #{response.body}"
    end
  end

  def test_remove_credentials_fail
    InfrastructureFacade.get_registered_infrastructures.each do |facade_id, info|
      info[:facade].class.any_instance.expects(:remove_credentials).throws(StandardError.new 'some error').once
      get :remove_credentials, {infrastructure_name: facade_id, record_id: 1, type: 'secrets'},
          {user: @tmp_user_id}

      assert_equal 'error', JSON.parse(response.body)['status'], "facade: #{facade_id}, response: #{response.body}"
    end
  end

end