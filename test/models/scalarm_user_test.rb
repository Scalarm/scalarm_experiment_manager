require 'minitest/autorun'
require 'test_helper'
require 'mocha'

class ScalarmUserTest < MiniTest::Test

  ## example of PL-Grid Scalarm User
  # #<#<Class:0x007fa2ccfa6880>:0x007fa2ccf9e9c8
  # @attributes={"_id"=>BSON::ObjectId('5565cf33369ffd0350000002'),
  # "dn"=>"/C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput",
  # "login"=>"plgjliput", "credentials_failed"=>{"scalarm"=>[2015-07-16 09:39:20 UTC]}}>

  def test_detect_valid_plgrid_user
    dn = "/C=PL/O=PL-Grid/O=Uzytkownik/O=AGH/CN=Jakub Liput/CN=plgjliput"
    user = ScalarmUser.new(login: 'plgjliput', dn: dn)

    assert user.pl_grid_user?
  end

  def test_detect_invalid_plgrid_user
    dn = "/C=PL/O=Other/O=Admin/O=AGH/CN=Jakub Liput/CN=plgjliput"
    user = ScalarmUser.new(login: 'plgjliput', dn: dn)

    refute user.pl_grid_user?
  end

end

