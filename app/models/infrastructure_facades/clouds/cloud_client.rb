# Methods to implement by subclasses:
# - vm_instance(instance_id) -> specific CloudVmInstance
# - all_vm_instances() -> Hash<instance_id => specific CloudVmInstance>


class CloudClient

  # @param [CloudSecrets] secrets credentials to authenticate to cloud service
  def initialize(secrets)
    @secrets = secrets
  end

end