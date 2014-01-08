# Methods to implement by subclasses:
# - all_vm_ids -> list of all vm instances ids
# - create_instances(base_instace_name, image_id, number) => list of AbstractVmInstance


class AbstractCloudClient

  # @param [CloudSecrets] secrets credentials to authenticate to cloud service
  def initialize(secrets)
    @secrets = secrets
  end

  def vm_instance(instance_id)
    VmInstance.new(instance_id, self)
  end

  # @return [Hash] instance_id => specific AbstractVmInstance
  def all_vm_instances
    all_vm_ids.map {|i| vm_instance(i)}
  end

end