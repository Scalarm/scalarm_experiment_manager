#require 'libvirt'

class PhysicalMachine < ActiveRecord::Base
  has_many :virtual_machines, :dependent => :destroy
  #before_destroy :close_libvirt_connection

  def get_libvirt_connection
    #if @conn.nil? || @conn.closed? then
    #  @conn = Libvirt::open("qemu+ssh://#{username}@#{ip}/system")
    #end
    #
    #@conn
    nil
  end

  def close_libvirt_connection
    #if @conn && !@conn.closed?
    #  @conn.close
    #end
  end

end
