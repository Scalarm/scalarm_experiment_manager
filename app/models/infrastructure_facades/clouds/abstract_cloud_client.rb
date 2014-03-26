# Methods to implement by subclasses:
# - all_images_info -> get array of hashes: image_id => image_name for all images permitted to use by cloud user
# - instantiate_vms(base_instace_name, image_id, number) => list of instance ids
# - all_images_info -> return array of hashes: image_id =>
# Methods for checking and changing virtual machine state (taking vm id)
# - state -> one of: [:intializing, :running, :deactivated, :rebooting, :error]
# - exists? -> true if VM exists (instance with given @instance_id is still available)
# - terminate -> nil -- terminates VM
# - reinitialize -> nil -- reinitializes VM (should work for ALL states)
# - public_host -> String: public host of VM -- dynamically gets hostname from API
# - public_ssh_port -> String: public ssh port of VM -- dynamically gets hostname from API
# Class methods
# - self.instance_types -> Hash<String, String>: instance type desc -> instance type id
# VM states:
#  -- initializing (after creation and before running)
#  -- running (booting and running)
#  -- deactivated (after running - machine was send to stop, terminate or deletion)
#  -- rebooting
#  -- error (state that shouldn't occur)

require_relative 'vm_instance'
require_relative 'scheduled_vm_instance'

class AbstractCloudClient

  # @param [CloudSecrets] secrets credentials to authenticate to cloud service
  def initialize(secrets)
    @secrets = secrets
  end

  def valid_credentials?
    begin
      not all_vm_ids.nil?
    rescue
      false
    end
  end

  def vm_instance(instance_id)
    VmInstance.new(instance_id.to_s, self)
  end

  def scheduled_vm_instance(vm_record)
    ScheduledVmInstance.new(vm_record, self)
  end

  # @return [Hash] instance_id => specific AbstractVmInstance
  def all_vm_instances
    Hash[all_vm_ids.map {|i| [i, vm_instance(i)]}]
  end

  # standard implementation - can be overriden to more specific
  def exists?(id)
    all_vm_ids.include?(id)
  end

  # return specific info about VmRecord for specific clous
  # by default it is blank -- should be overriden in concrete CloudClient
  def vm_record_info(vm_record)
    ''
  end

  def image_exists?(image_id)
    all_images_info.keys.include? image_id
  end

end