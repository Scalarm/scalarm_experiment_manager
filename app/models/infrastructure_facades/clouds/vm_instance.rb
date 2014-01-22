# Provides utils for virtual machines operations
class VmInstance

  def initialize(instance_id, cloud_client)
    @client = cloud_client
    @instance_id = instance_id
  end

  def vm_id
    @instance_id
  end

  # -- delegation methods --

  def name
    exists? and @client.name(@instance_id)
  end

  def status
    @client.status(@instance_id)
  end

  def exists?
    @client.exists?(@instance_id)
  end

  def terminate
    @client.terminate(@instance_id)
  end

  def reinitialize
    @client.reinitialize(@instance_id)
  end

  def public_ssh_address
    @client.public_ssh_address(@instance_id)
  end

end