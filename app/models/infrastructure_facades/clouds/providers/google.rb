require 'infrastructure_facades/clouds/abstract_cloud_client'
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

#    def network_url(project, network_name)
#      "#{BASE_URL}/#{project}/global/networks/default"
#    end
#
#    API_VERSION = 'v1'
#    BASE_URL = "https://www.googleapis.com/compute/#{API_VERSION}/projects"
#    DEFAULT_ZONE_NAME = 'us-central1-a'
#
#    # DEFAULT_ZONE_URL = BASE_URL + DEFAULT_PROJECT + '/global/zones/' + DEFAULT_ZONE_NAME
#
#    #DEFAULT_MACHINE = "#{BASE_URL}/#{DEFAULT_PROJECT}/zones/#{DEFAULT_ZONE_NAME}/machineTypes/#{DEFAULT_INSTANCE_TYPE}"
#    #DEFAULT_NETWORK = "#{BASE_URL}/#{DEFAULT_PROJECT}/global/networks/default"
#
#    secret_google_email = '724529945327@developer.gserviceaccount.com'
#
## Creating a new API client and loading the Google Compute Engine API.
#
#    path_to_key_file ="privatekey.p12"
#    secret_passphrase = "notasecret"
#    secret_key_content = nil
#    File::open(path_to_key_file, 'rb') {|f| secret_key_content = f.read}
#    raise 'no key content' if secret_key_content.nil?
#    key = Google::APIClient::KeyUtils.load_from_pkcs12(secret_key_content, secret_passphrase)
#
#    asserter = Google::APIClient::JWTAsserter.new(
#        secret_google_email,
#        'https://www.googleapis.com/auth/compute',
#        key)
#
#    client.authorization = asserter.authorize()
#
#    compute = client.discovered_api('compute', API_VERSION)



    def initialize(secrets)
      super(secrets)
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

    # TODO error handling method?

    # TODO images can be fetch from various sources (eg. debian-cloud) and user repo
    # TODO which we should use?
    def all_images_info
      result = execute @compute_api.images.list, project: @secrets.project
      raise result.error_message if result.error?
      result_hash = JSON.parse(result.body)
      Hash[result_hash['items'].map {|i| [i['selfLink'], i['name']]}]
    end

    def all_vm_ids
      result = execute @compute_api.instances.list, project: @secrets.project, zone: DEFAULT_ZONE
      raise result.error_message if result.error?
      result_hash = JSON.parse(result.body)
      result_hash['items'].map {|i| i['selfLink']}
    end

    def instantiate_vms(base_name, image_id, number, params)
      result = execute @compute_api.instances.insert, {project: @secrets.project, zone: DEFAULT_ZONE}, {
          'machineType' => params[:instance_type],
          name: "scalarm-#{SecureRandom.uuid}",
          'networkingInterfaces' => [ {'accessConfigs'=>[{name: 'External NAT', type: 'ONE_TO_ONE_NAT'}],
                                      network: network_url} ],
          disks: [ {boot: true, type: 'PERSISTENT', mode: 'READ_WRITE', 'autoDelete'=>true, 'initializeParams'=>{
              'sourceImage'=>image_url(image_id)
          }} ]
      }
      #done_result = wait_for_done(result_hash['name'])
      # disk 'deviceName'
    end


    ## -- VM instance methods --

    STATES_MAPPING = {
      pending: :initializing,
      running: :running,
      shutting_down: :deactivated,
      terminated: :deactivated,
      stopping: :deactivated,
      stopped: :deactivated
    }

    def status(id)
      STATES_MAPPING[ec2_instance(id).status]
    end

    def terminate(id)
      ec2_instance(id).terminate
    end

    def reinitialize(id)
      ec2_instance(id).reboot
    end

    # @return [Hash] {:ip => string cloud public ip, :port => string redirected port} or nil on error
    def public_ssh_address(id)
      {ip: ec2_instance(id).public_dns_name, port: '22'}
    end

    # TODO: translate or remove
    def vm_record_info(vm_record)
      "Type: #{instance_type}"
    end

    def exists?(id)
      ec2_instance(id).exists?
    end

    # TODO
    def self.instance_types
      {
          'f1.micro'=> 'Micro (TODO)'
      }
    end

    # --- Utils ---

    def instance_name
      ''
    end

    def operation_status(operation_name)
      result = client.execute(
          api_method: @compute_api.zone_operations.get,
          parameters: {
              project: @secrets.project,
              zone: DEFAULT_ZONE_NAME,
              operation: operation_name
          }
      )
      JSON.parse(result.body)['status']
    end

    def wait_for_done(operation_name)
      while (result = operation_status(operation_name)) != 'DONE'
        sleep 1
      end
      result
    end

    def execute(method, parameters, body=nil)
      query = {api_method: method}
      query.merge!({parameters: parameters})
      query.merge!({body: body}) if body

      result = @api_client.execute(query)
    end

    def network_url(network='default')
      "#{BASE_URL}/#{@secrets.project}/global/networks/#{network}"
    end

    def image_url(image_id)
      "#{BASE}/#{@secrets.project}/global/images/#{image_id}"
    end

  end

end