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
    secrets.stubs(:project).returns('...')

    @client = GoogleCloud::CloudClient.new(secrets)
  end

  def test_all_images_info
    puts @client.all_images_info
  end


end