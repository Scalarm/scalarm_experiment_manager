require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'gsi/ssh'
require 'gsi/scp'

class GsiSshTest < MiniTest::Test

  def setup
    @proxy = <<-STR
<<PROXY CERTIIFCATE FILE CONTENT>>
    STR

    @proxy.strip!
  end

  def test_ssh
    Gsi::SSH.start 'ui.cyfronet.pl', 'plguser', @proxy do |ssh|
      # puts ssh.exec! 'echo foo 1>&2'
      # puts ssh.exec! 'echo bar'
      # puts ssh.exec! 'uname -r'
      puts ssh.exec! 'date'
      # ssh.exec! 'echo'
      puts ssh.pop_leftovers.to_s
      puts ssh.pop_leftovers.to_s
    end
  end

  def test_scp
    Gsi::SCP.start 'ui.cyfronet.pl', 'plguser', @proxy do |scp|
      scp.upload_multiple! ['/home/user/file1.txt', '/home/user/file1.txt'], '.'
    end
  end

end