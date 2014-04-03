require 'infrastructure_facades/clouds/abstract_cloud_client'
require 'infrastructure_facades/infrastructure_error'
require 'google/api_client'
require 'google/api_client/auth/key_utils'
require 'json'

module GoogleCloud

  class CloudClient < AbstractCloudClient

    attr_reader :api_client
    attr_reader :compute_api

    API_VERSION = 'v1'
    DEFAULT_ZONE = 'us-central1-a'
    BASE_URL = "https://www.googleapis.com/compute/#{API_VERSION}/projects"

    def initialize(secrets)
      super(secrets)
      raise Infrastructure::InvalidCredentialsError unless check_secrets(secrets)
      @api_client = Google::APIClient.new(application_name: 'scalarm', application_version: 1)
      key = Google::APIClient::KeyUtils.load_from_pkcs12(secrets.secret_key_file, secrets.secret_key_passphrase)
      asserter = Google::APIClient::JWTAsserter.new(secrets.gservice_email,
                                                    'https://www.googleapis.com/auth/compute', key)
      @api_client.authorization = asserter.authorize
      @compute_api = @api_client.discovered_api('compute', API_VERSION)
    end

    def self.short_name
      'google'
    end

    def self.full_name
      'Google Compute Engine'
    end

    def all_images_info
      result = execute! @compute_api.images.list, project: @secrets.project
      result = parse_result(result)
      Hash[result['items'].map {|i| [i['name'], i['name']]}]
    end

    def all_vm_ids
      result = execute! @compute_api.instances.list, project: @secrets.project, zone: DEFAULT_ZONE
      result = parse_result(result)
      result.has_key?('items') ? result['items'].map {|i| i['name']} : []
    end

    # Blocks until all insert requests are done. Sends requests for each VM in separate thread.
    # @param [Hash] params additional params hash (Symbol => String): instance_type: one of self.instance_types string
    def instantiate_vms(base_name, image_id, number, params)
      throw 'no instance type specified' unless params.include?(:instance_type)
      ids_array_lock = Mutex.new
      ids_array = []
      threads = (1..number).map do
        Thread.start do
          instance_name = generate_instance_name(base_name)

          insert_body = instances_insert_body(instance_name, machine_type_url(params[:instance_type]),
                                       network_url, image_url(image_id))

          insert_result = parse_result(execute!(@compute_api.instances.insert,
                                                {project: @secrets.project, zone: DEFAULT_ZONE}, insert_body))
          wait_for_done(insert_result['name'])
          ids_array_lock.synchronize do
            ids_array << instance_name
          end
        end
      end
      threads.map &:join

      ids_array
    end


    ## -- VM instance methods --
    # initializing, running, deactivated, error

    #PROVISIONING - Resources are being reserved for the instance. The instance isn't running yet.
    #STAGING - Resources have been acquired and the instance is being prepared for launch.
    #RUNNING - The instance is booting up or running. You should be able to ssh into the instance soon, though not immediately, after it enters this state.
    #STOPPING - The instance is being stopped either due to a failure, or the instance being shut down. This is a temporary status and the instance will move to either PROVISIONING or TERMINATED.
    #STOPPING - The instance is in the process of being stopped.
    #TERMINATED - The instance either failed for some reason or was shutdown. This is a permanent status, and the only way to repair the instance is to delete and recreate it.

    STATES_MAPPING = {
      "PROVISIONING"=> :initializing,
      "STAGING"=> :initializing,
      "RUNNING"=> :running,
      "STOPPING"=> :deactivated,
      "STOPPED"=> :deactivated,
      "TERMINATED"=> :deactivated
    }

    def status(id)
      STATES_MAPPING[parse_result(get_instance_info(id))['status']]
    end

    def terminate(id)
      instance_delete(id)
    end

    # WARNING: instance remains in RUNNING state through the reset
    def reinitialize(id)
      instance_reset(id)
    end

    # @return [Hash] {:ip => string cloud public ip, :port => string redirected port} or nil on error
    def public_ssh_address(id)
      {
          host: parse_result(get_instance_info(id))['networkInterfaces'][0]['accessConfigs'][0]['natIP'],
          port: '22'
      }
    end

    def instance_types
      Hash[(parse_result(get_instance_types)['items'].select {|i| not i.has_key? 'deprecated'}).map do |i|
        [i['name'], "#{i['name']}: #{i['guestCpus']} CPUs, #{i['memoryMb']} MB RAM"]
      end]
    end

    # --- Utils ---

    def generate_instance_name(base)
      "scalarm-#{SecureRandom.hex(8)}"
    end

    def operation_status(operation_name)
      result = execute! @compute_api.zone_operations.get, project: @secrets.project, zone: DEFAULT_ZONE,
                       operation: operation_name
      JSON.parse(result.body)['status']
    end

    def wait_for_done(operation_name)
      while (result = operation_status(operation_name)) != 'DONE'
        sleep 1
      end
      result
    end

    def execute!(method, parameters, body=nil)
      query = {api_method: method}
      query.merge!({parameters: parameters})
      query.merge!({body_object: body}) if body

      @api_client.execute!(query)
    end

    def network_url(network='default')
      "#{BASE_URL}/#{@secrets.project}/global/networks/#{network}"
    end

    def image_url(image_id)
      "#{BASE_URL}/#{@secrets.project}/global/images/#{image_id}"
    end

    def machine_type_url(machine_type)
      "#{BASE_URL}/#{@secrets.project}/zones/#{DEFAULT_ZONE}/machineTypes/#{machine_type}"
    end

    def parse_result_or_raise_error(result)
      raise result.error_message if result.error?
      JSON.parse(result.body)
    end
    
    def parse_result(result)
      JSON.parse(result.body)
    end

    def get_instance_info(instance_name)
      execute! @compute_api.instances.get, instance: instance_name, project: @secrets.project, zone: DEFAULT_ZONE
    end

    def instance_delete(instance_name)
      execute! @compute_api.instances.delete, instance: instance_name, project: @secrets.project, zone: DEFAULT_ZONE
    end

    # Google doc: Performing a reset on your instance is similar to pressing the reset button on your computer.
    # Note that your instance remains in RUNNING mode through the reset.
    def instance_reset(instance_name)
      execute! @compute_api.instances.reset, instance: instance_name, project: @secrets.project, zone: DEFAULT_ZONE
    end

    def instances_insert_body(instance_name, machine_type_url, network_url, image_id)
      {
          machineType: machine_type_url,
          name: instance_name,
          networkInterfaces: [ {accessConfigs: [{name: 'External NAT', type: 'ONE_TO_ONE_NAT'}],
                                   network: network_url} ],
          disks: [ {boot: true, type: 'PERSISTENT', mode: 'READ_WRITE', autoDelete: true,
                    deviceName: 'scalarm-root',
                    initializeParams: {sourceImage: image_id}
                   } ]
      }
    end

    def get_instance_types
      execute! @compute_api.machine_types.list, project: @secrets.project, zone: DEFAULT_ZONE
    end

    def check_secrets(secrets)
      secrets.secret_key_file and secrets.secret_key_passphrase and secrets.gservice_email and secrets.project
    end

  end

end