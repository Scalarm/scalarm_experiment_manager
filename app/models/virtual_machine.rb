class VirtualMachine < ActiveRecord::Base
  belongs_to :physical_machine

  def self.state_string(state)
    case state
      when 1 then "running"
      when 3 then "paused"
      when 5 then "shutdown"
    end
  end

  def current_state
    #conn = physical_machine.get_libvirt_connection
    #domain = conn.lookup_domain_by_name name
    #state = domain.info.state
    #
    #VirtualMachine.state_string(state)
  end

end
