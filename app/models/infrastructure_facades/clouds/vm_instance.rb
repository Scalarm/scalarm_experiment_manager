# Methods:
# - name -> String: name of virtual machine instance
# - state -> one of: [:pending, :running, :shutting_down, :terminated, :stopping, :stopped]
# - exists? -> true if VM exists (instance with given @instance_id is still available)
# - terminate -> nil -- terminates VM
# - public_host -> String: public host of VM -- dynamically gets hostname from API
# - public_ssh_port -> String: public ssh port of VM -- dynamically gets hostname from API

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
    @client.name(@instance_id)
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

  def public_ssh_address
    @client.public_ssh_address(@instance_id)
  end

end