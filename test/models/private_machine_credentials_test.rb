require 'minitest/autorun'
require 'test_helper'
require 'mocha'
require 'net/ssh'

class PrivateMachineCredentialsTest < Minitest::Test

  def setup
    @credentials = PrivateMachineCredentials.new({host: 'localhost', port: 22, login: 'secret'})
    @credentials.password = 'secret'

    @linux_x86_64 = "Warning! PATH is not properly set up, '/nfs/asd/darek/.rvm/gems/ruby-2.1.5/bin' is not at first place,
             usually this is caused by shell initialization files - check them for 'PATH=...' entries,
             it might also help to re-add RVM to your dotfiles: 'rvm get stable --auto-dotfiles',
             to fix temporarily in this shell session run: 'rvm use ruby-2.1.5'.
    ruby-2.2.1 is not installed.
    To install do: 'rvm install ruby-2.2.1'
    Linux darek.isi.edu 3.17.3-200.fc20.x86_64 #1 SMP Fri Nov 14 19:45:42 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux"
    @linux_x86 = "Warning! PATH is not properly set up, '/nfs/asd/darek/.rvm/gems/ruby-2.1.5/bin' is not at first place,
                 usually this is caused by shell initialization files - check them for 'PATH=...' entries,
                 it might also help to re-add RVM to your dotfiles: 'rvm get stable --auto-dotfiles',
                 to fix temporarily in this shell session run: 'rvm use ruby-2.1.5'.
        Linux darek.isi.edu 3.17.3-200.fc20.x86 #1 SMP Fri Nov 14 19:45:42 UTC 2014 x86 x86 x86 GNU/Linux"
    @mac_x86_64 = "Darwin myc-wifi.local 15.0.0 Darwin Kernel Version 15.0.0: Sat Sep 19 15:53:46 PDT 2015; root:xnu-3247.10.11~1/RELEASE_X86_64 x86_64"
    @mac_x86 = "Darwin myc-wifi.local 15.0.0 Darwin Kernel Version 15.0.0: Sat Sep 19 15:53:46 PDT 2015; root:xnu-3247.10.11~1/RELEASE_X86 x86"

    @ssh_session = mock()
    @ssh_session.stubs(:closed?).returns(true)

    super
  end

  def test_os_and_arch_setting_linux_x86
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@linux_x86)

    @credentials.discover_os_and_arch(@ssh_session)

    assert_equal "linux", @credentials.os
    assert_equal "x86", @credentials.arch
  end

  def test_os_and_arch_setting_linux_x86_64
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@linux_x86_64)

    @credentials.discover_os_and_arch(@ssh_session)

    assert_equal "linux", @credentials.os
    assert_equal "x86_64", @credentials.arch
  end

  def test_os_and_arch_setting_mac_x86
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@mac_x86)

    @credentials.discover_os_and_arch(@ssh_session)

    assert_equal "darwin", @credentials.os
    assert_equal "x86", @credentials.arch
  end

  def test_os_and_arch_setting_mac_x86_64
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@mac_x86_64)

    @credentials.discover_os_and_arch(@ssh_session)

    assert_equal "darwin", @credentials.os
    assert_equal "x86_64", @credentials.arch
  end

  def test_os_and_arch_string_parsing
    parsed_os_and_arch = @credentials.parse_os_and_arch_string(@linux_x86)
    assert_equal "linux", parsed_os_and_arch["os"]
    assert_equal "x86", parsed_os_and_arch["arch"]

    parsed_os_and_arch = @credentials.parse_os_and_arch_string(@linux_x86_64)
    assert_equal "linux", parsed_os_and_arch["os"]
    assert_equal "x86_64", parsed_os_and_arch["arch"]

    parsed_os_and_arch = @credentials.parse_os_and_arch_string(@mac_x86)
    assert_equal "darwin", parsed_os_and_arch["os"]
    assert_equal "x86", parsed_os_and_arch["arch"]

    parsed_os_and_arch = @credentials.parse_os_and_arch_string(@mac_x86_64)
    assert_equal "darwin", parsed_os_and_arch["os"]
    assert_equal "x86_64", parsed_os_and_arch["arch"]
  end

  def test_os_and_arch_setting_through_validation_linux_x86
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@linux_x86)
    @credentials.stubs("_get_ssh_session").returns(@ssh_session)

    valid = @credentials.valid?

    assert_equal true, valid

    assert_equal "linux", @credentials.os
    assert_equal "x86", @credentials.arch
  end

  def test_os_and_arch_setting_through_validation_linux_x86_64
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@linux_x86_64)
    @credentials.stubs("_get_ssh_session").returns(@ssh_session)

    valid = @credentials.valid?

    assert_equal true, valid

    assert_equal "linux", @credentials.os
    assert_equal "x86_64", @credentials.arch
  end

  def test_os_and_arch_setting_through_validation_mac_x86
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@mac_x86)
    @credentials.stubs("_get_ssh_session").returns(@ssh_session)

    valid = @credentials.valid?

    assert_equal true, valid

    assert_equal "darwin", @credentials.os
    assert_equal "x86", @credentials.arch
  end

  def test_os_and_arch_setting_through_validation_mac_x86_64
    @ssh_session.stubs(:exec!).with("/bin/bash -i -c 'uname -a'").returns(@mac_x86_64)
    @credentials.stubs("_get_ssh_session").returns(@ssh_session)

    valid = @credentials.valid?

    assert_equal true, valid

    assert_equal "darwin", @credentials.os
    assert_equal "x86_64", @credentials.arch
  end

end