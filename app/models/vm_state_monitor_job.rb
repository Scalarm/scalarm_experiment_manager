#require 'libvirt'

class VMStateMonitorJob < Struct.new(:id)
  include ApplicationHelper, ActionView::Helpers::AssetTagHelper
  
  def perform
    while true
      vm = VirtualMachine.find(:id)
      current_state = vm.current_state
      if vm.state != current_state then
        vm.state = current_state
        vm.save
        Socky.send("$.get('/infrastructure/update_vm?vm_id=#{vm.id}', function(data) { eval(data); });")
      end
      sleep 10
    end
  end
end
