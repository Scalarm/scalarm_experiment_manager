class ExperimentStateMonitorJob < Struct.new(:url)
  include ApplicationHelper, ActionView::Helpers::AssetTagHelper
  
  def perform
    while true
      vms = VirtualMachine.find :all
      vms.each do |vm|
#        puts "State monitoring loop - #{url}"
        current_state = vm.current_state
        puts "Current state is #{current_state}"

        if vm.state != current_state then
          vm.state = current_state
          vm.save
          # Socky.send("$.get('/infrastructure/update_vm?vm_id=#{vm.id}', function(data) { eval(data); });")
        end
      end
      sleep 10
    end
  end
end
