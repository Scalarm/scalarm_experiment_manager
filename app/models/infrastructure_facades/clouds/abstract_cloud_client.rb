# Methods to implement by subclasses:
# - all_images_info -> get array of hashes: image_identifier => image label for all images permitted to use by cloud user
# - instantiate_vms(base_instace_name, image_id, number) => list of instance ids (Strings)
# - all_vm_ids -> get array of VM ids (Strings)
# - get_resource_configurations(user_id) -> list of hashes representing distinct configurations of infrastructure
# Methods for checking and changing virtual machine state (taking vm id)
# - status -> one of: [:intializing, :running, :deactivated, :rebooting, :error]
# - exists? -> true if VM exists (instance with given @instance_id is still available)
# - terminate -> nil -- terminates VM
# - reinitialize -> nil -- reinitializes VM (should work for ALL states)
# - public_ssh_address-> Hash: {host: ssh_host, port: ssh_port} for vm
# - instance_types -> Hash<String, String>: instance type desc -> instance type id
# VM states:
#  -- :initializing (after creation and before running)
#  -- :running (booting and running)
#  -- :deactivated (after running - machine was send to stop, terminate or deletion)
#  -- :rebooting
#  -- :error (state that shouldn't occur)

require_relative 'vm_instance'

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

  ##
  # Returns list of hashes representing distinct resource configurations
  # Resource configurations are distinguished by:
  #  * type of machine instance
  #  * image secrets
  # @param user_id [BSON::ObjectId, String]
  # @return [Array<Hash>] list of resource configurations
  def get_resource_configurations(user_id)
    instance_types_list = instance_types.map { |type, _| type }
    image_secrets_ids = CloudImageSecrets
        .find_all_by_query(user_id: user_id, cloud_name: self.class.short_name.to_s)
        .map { |i| i.id }

    instance_types_list.flat_map do |instance_type|
      image_secrets_ids.flat_map do |image_secret_id|
        {name: self.class.short_name.to_sym, params: {image_secrets_id: image_secret_id, instance_type: instance_type}}
      end
    end
  end

end