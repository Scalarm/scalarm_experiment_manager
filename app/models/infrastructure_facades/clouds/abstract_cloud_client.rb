# Methods to implement by subclasses:
# - all_vm_ids -> list of all vm instances ids
# - schedule_vm_instances(base_instace_name, image_id, number) => list of AbstractVmInstance
# Methods for checking and changing virtual machine state (taking vm id)
# - name -> String: name of virtual machine instance # TODO: deprecated
# - state -> one of: [:intializing, :running, :deactivated, :rebooting, :error]
# - exists? -> true if VM exists (instance with given @instance_id is still available)
# - terminate -> nil -- terminates VM
# - reinitialize -> nil -- reinitializes VM (should work for ALL states)
# - public_host -> String: public host of VM -- dynamically gets hostname from API
# - public_ssh_port -> String: public ssh port of VM -- dynamically gets hostname from API

# VM states:
#  -- initializing (after creation and before running)
#  -- running (booting and running)
#  -- deactivated (after running - machine was send to stop, terminate or deletion)
#  -- rebooting
#  -- error (state that shouldn't occur)

require_relative 'vm_instance'

class AbstractCloudClient

  # @param [CloudSecrets] secrets credentials to authenticate to cloud service
  def initialize(secrets)
    @secrets = secrets
  end

  def vm_instance(instance_id)
    VmInstance.new(instance_id.to_s, self)
  end

  # @return [Hash] instance_id => specific AbstractVmInstance
  def all_vm_instances
    Hash[all_vm_ids.map {|i| [i, vm_instance(i)]}]
  end

  def exists?(id)
    all_vm_ids.include?(id)
  end

  # TODO: use
  # return specific info about VmRecord for specific clous
  # by default it is blank -- should be overriden in concrete CloudClient
  def vm_record_info(vm_record)
    ''
  end

end