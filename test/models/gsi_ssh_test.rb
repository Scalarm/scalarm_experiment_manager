require 'minitest/autorun'
require 'test_helper'
require 'mocha'

require 'gsi/ssh'

class GsiSshTest < MiniTest::Test

  def test_dummy
    Gsi::SSH.start 'ui.cyfronet.pl', 'plgjliput', '/home/kliput/x509up_u20762b' do |ssh|
      puts ssh.exec! 'echo foo 1>&2'
      puts ssh.exec! 'echo bar'
      puts ssh.exec! 'uname -r'
#     puts ssh.exec! 'date'
      puts ssh.pop_leftovers.to_s
      puts ssh.pop_leftovers.to_s
    end
  end

end