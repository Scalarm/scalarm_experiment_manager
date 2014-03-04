require 'test/unit'

class PLCloudClientTest < Test::Unit::TestCase

  # README
  # This test needs valid:
  # - ScalarmUser with 'login' as TEST_USER_LOGIN
  # - PLCloudSecrets with:
  #   - 'user_id' as previous ScalarmUser.id
  #   - 'login' to PLCloud
  #   - 'password' to PLCloud
  # - PLCloudImage with:
  #   - 'user_id' as previous ScalarmUser.id
  #   - 'image_id'
  #   - 'login' (to VM)
  #   - 'password' (to VM)
  #
  # Provided credentials will be used to create, execute SSH command and delete
  # VM instantiated from image with given image_id.
  #
  # NOTE: please check if machines were successfully deleted after tests.

  TEST_USER_LOGIN = '__pl_cloud_test_user__'

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_everything

    # --- login ---

    user = ScalarmUser.find_by_login(TEST_USER_LOGIN)
    assert(user, "Test user #{TEST_USER_LOGIN} not available.
      Please create valid ScalarmUser with this login and associated PLCloudCredentials (see comments in test source file).")
    secrets = PLCloudSecrets.find_by_user_id(user.id)
    assert(secrets, "No PLCloud for user #{TEST_USER_LOGIN}.
      Please create associated PLCloudSecrets for this user (see comments in test source file).")
    image = PLCloudImage.find_by_user_id(user.id)
    assert(image, "No PLCloud for user #{TEST_USER_LOGIN}.
      Please create associated PLCloudImage for this user (see comments in test source file).")
    plcc = PLCloudUtil.new(secrets)

    # --- create ---

    start_vm_num = plcc.all_vm_info.length

    create_vm_num = 1
    created_ids = plcc.create_instances('scalarm_test', image.image_id, create_vm_num)

    assert_equal(created_ids.count, create_vm_num)

    assert(created_ids.all? {|id| id > 0}, "Some of created VM's have id <= 0: #{created_ids}.
      \nPLEASE REMOVE CREATED MACHINES MANUALLY!")

    assert_equal(plcc.all_vm_info.length, start_vm_num + create_vm_num)

    # --- info ---

    instances = created_ids.map {|id| plcc.vm_instance(id) }

    assert(instances.all? {|i| i.exists?})

    # check if created machines have id as it was requested on creation
    instances.each do |info|
      assert_equal(info.vm_id, info.info['ID'].to_i,
                  "VM id from constructor does not match fetched for:\n#{info.info}")
    end

    # --- redirect ssh port ---

    assert(instances.all? {|inst| not inst.redirections.has_key? 22},
           "Some new VM instance already has port 22 redirected.")

    ssh_redirections = instances.map {|inst| inst.redirect_port(22).merge(instance: inst)}

    assert(ssh_redirections.all? {|rdr| rdr.count == 3})

    assert(instances.all? {|inst| inst.redirections.has_key? 22},
           "Some VM instances has port 22 not redirected after redirection.")

    # --- invoke command via ssh ---

    ssh_redirections.each do |rdr|
      vm_instance = rdr[:instance]

      stat_i = 10
      while stat_i > 0 and vm_instance.short_lcm_state != 'runn'
        sleep(8)
        stat_i -= 1
      end

      assert(stat_i > 0)

      error_counter = 0
      while true
        begin
          # use only login/password on ssh
          output = Net::SSH.start(rdr[:ip], image.login, port: rdr[:port],
                         password: image.password, auth_methods: %w(password)) do |ssh|
            ssh.exec!('echo hello')
          end
          assert_equal(output, "hello\n", "VM: #{rdr[:ip]}:#{rdr[:port]} gives ouput: #{output} on 'echo hello' via SSH")
          break
        rescue Exception => e
          puts "Exception #{e} occured while communication with #{rdr[:ip]}:#{rdr[:port]} --- #{error_counter}"
          error_counter += 1
          assert(error_counter <= 10, "Max SSH connections tries for #{rdr[:ip]}:#{rdr[:port]} exceeded.")
        end

        sleep(5)
      end

    end

    # --- delete ---

    instances.each {|inst| inst.delete}

    assert_equal(plcc.all_vm_info.length, start_vm_num)
    assert(instances.all? {|i| not i.exists?})

  end
end