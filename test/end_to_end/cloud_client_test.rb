require 'test_helper'
require 'mocha'
require 'test/unit'
require 'infrastructure_facades/clouds/providers/google'

class CloudClientTest < Test::Unit::TestCase

  def setup
    MongoActiveRecord.connection_init('localhost', 'scalarm_db_test')
    MongoActiveRecord.get_database('scalarm_db_clouds_test')

    # TODO store in test database
    secrets = Object
    key_file = nil
    File.open('...', 'rb') {|f| key_file = f.read}
    raise 'no key file' if key_file.blank?
    secrets.stubs(:secret_key_file).returns(key_file)
    secrets.stubs(:secret_key_passphrase).returns('...')
    secrets.stubs(:gservice_email).returns('...')
    secrets.stubs(:project).returns('scalarm-tests-1')

    @client = GoogleCloud::CloudClient.new(secrets)
  end

  def test_all_images_info
    puts @client.all_images_info
  end

  def test_instantiate_vms
    image_id = @client.all_images_info.keys[0]
    assert_not_nil image_id
    puts image_id

    #info = @client.get_instance_info('scalarm-fb53ab3b-f50d-4d26-92b5-6adf79c7922e')
    #puts info.body
    #puts '---'
    #puts @client.status('scalarm-fb53ab3b-f50d-4d26-92b5-6adf79c7922e')
    #puts @client.public_ssh_address('scalarm-fb53ab3b-f50d-4d26-92b5-6adf79c7922e')

    vm_ids = @client.instantiate_vms('test', image_id, 1, instance_type: 'f1-micro')
    puts vm_ids
    assert_equal 1, vm_ids.count

    assert vm_ids.all? {|id| @client.exists?(id)}
  end

  def test_reinitialize
    puts 'before reinit'
    puts @client.status('scalarm-8f1b527a-b563-4db1-beaa-876961a55537')
    @client.reinitialize('scalarm-8f1b527a-b563-4db1-beaa-876961a55537')
    puts 'after reinit'
    puts @client.status('scalarm-8f1b527a-b563-4db1-beaa-876961a55537')
  end

  def test_terminate_all
    @client.all_vm_ids.map {|id| @client.terminate(id)}
    puts @client.all_vm_ids
    puts @client.all_vm_ids.map {|id| @client.status(id)}
    puts @client.all_vm_ids.map {|id| @client.exists?(id)}
  end

  def test_exists
    puts @client.exists?('scalarm-1f386129-a4b6-4077-87db-ca0c22a3d532')
  end

end
