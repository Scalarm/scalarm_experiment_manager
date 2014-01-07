# Methods to implement by subclasses:
# - name -> String: name of virtual machine instance
# - state -> one of: [:pending, :running, :shutting_down, :terminated, :stopping, :stopped]
# - exists? -> true if VM exists (instance with given id is still available)
# - terminate -> terminates VM

# Provides utils for virtual machines operations
class CloudVmInstance
end