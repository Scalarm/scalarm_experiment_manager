require 'test_helper'
require 'mocha'
require 'minitest/autorun'
require 'infrastructure_facades/clouds/cloud_facade_factory'
require 'net/ssh'

class CloudClientsTest < MiniTest::Test

  # NOTICE: These tests should be used carefully because instatniating VM's causes costs.
  # Please check running VMs on Cloud service before and after using tests,
  # because faulty clients or wrong credentials can cause remain of created intances.
  # Tests can be launched by uncommenting cloud-specific tests in bottom of this file.

  def setup
    collection_name = 'scalarm_db_clouds_test'
    MongoActiveRecord.connection_init('localhost', collection_name)
    MongoActiveRecord.get_database(collection_name)
  end

  def self.create_test_for_cloud(cloud_name, cloud_image, instance_type, params={})
    vm_count = 1

    define_method "test_#{cloud_name}" do
      # secrets in database
      secrets = CloudSecrets.find_by_cloud_name(cloud_name)
      assert_not_nil secrets, "no secrets found for #{cloud_name} in database, please create"

      # client class validation
      client_class = Scalarm::CloudFacadeFactory.instance.client_class(cloud_name)
      assert_not_nil client_class
      [:short_name, :long_name].each do |method_name|
        assert_respond_to client_class, method_name
      end

      # client instance construction and validation
      client = nil
      assert_nothing_thrown { client = client_class.new(secrets) }
      assert_not_nil client
      [:all_images_info, :instantiate_vms, :all_vm_ids, :status, :exists?,
       :terminate, :reinitialize, :public_ssh_address, :instance_types].each do |method_name|
        assert_respond_to client, method_name, "client #{client_class} missing method #{method_name.to_s}"
      end

      # all_images_info
      images = client.all_images_info
      assert_not_nil images
      assert_include images, cloud_image, "no image with id #{cloud_image} available in cloud service, please create"

      # image secrets from database
      image_secrets = CloudImageSecrets.find_by_query cloud_name: cloud_name, image_id: cloud_image
      assert_not_nil image_secrets, "no image with image_id #{cloud_image} credentials for #{cloud_name} in database, please create"

      # instance types
      instance_types = client.instance_types
      assert_not_nil instance_types
      assert_include instance_types, instance_type, "no instance type #{instance_type} available in #{cloud_name} cloud"

      # all_vm_ids - existing vms
      before_instantiate_vms = client.all_vm_ids
      assert_not_nil before_instantiate_vms
      assert_respond_to before_instantiate_vms, :each
      assert before_instantiate_vms.all? {|i| client.exists?(i)}

      # NOTICE - this can cause costs: instantiate vms
      instance_ids = []
      assert_nothing_thrown do
        instance_ids = client.instantiate_vms('scalarm-testing', cloud_image, vm_count,
                                              {instance_type: instance_type}.merge(params))
      end
      assert_not_nil instance_ids
      assert_equal vm_count, (instance_ids-before_instantiate_vms).count,
                   "wrong vms list after initialization, before: #{before_instantiate_vms}, after: #{instance_ids}"
      assert instance_ids.all? {|i| client.exists?(i)}

      # check ssh connection to VMs

      (instance_ids.map {|id| client.vm_instance(id)}).each do |vm|
        vm_wait_for_status(vm, :running)
        vm_try_ssh(vm, image_secrets)
        vm.reinitialize
        vm_wait_for_status(vm, :running)
        vm_try_ssh(vm, image_secrets)
      end

      (instance_ids.map {|id| client.vm_instance(id)}).each do |vm|
        vm.terminate
        vm_wait_for_status(vm, :deactivated)
      end

    end
  end

  def vm_wait_for_status(vm, status)
    assert_nothing_thrown do
      Timeout::timeout(60*5) do
        until vm.status == status do
          sleep 5
        end
      end
    end
  end

  def vm_try_ssh(vm, image_secrets)
    ssh_address = vm.public_ssh_address
    assert_not_nil ssh_address
    assert_include ssh_address, :host
    assert_include ssh_address, :port

    tries = 0
    loop do
      begin
        Net::SSH.start(ssh_address[:host], image_secrets.image_login, port: ssh_address[:port],
                  password: image_secrets.secret_image_password, auth_methods: %w(password)) do |ssh|
          echo_output = ssh.exec! 'echo hello'
          assert_operator echo_output, :=~, /^hello/
        end
        break
      rescue Exception => e
        puts "SSH connection error: #{e}"
        assert_operator tries, :<, 30, e.to_s
        sleep 5
      end
    end
  end

  # -- TESTS --
  # please uncomment!
  # NOTICE: image ids should be changed manually to corresponding image_id in CloudImageSecrets

  #create_test_for_cloud 'amazon', 'ami-cbf2cfa2', 't1.micro', security_group: 'quicklaunch-1'
  #create_test_for_cloud 'google', 'scalarm-1', 'f1-micro'
  #create_test_for_cloud 'pl_cloud', '138', 'standard'

end