require 'rest-client'

class PLCloudClient
  PLCLOUD_URL = 'https://149.156.10.32:3443'

  RE_TEMPLATE_ID = /ID: (\d+)/
  RE_VM_ID = /VM ID: (\d+)/

  # @param [PLCloudSecrets] secrets secrets used to authenticate to PLCloud REST service
  def initialize(secrets)
    @secrets = secrets
  end


  # @return [Integer] created template id or -1 on error
  def create_template(name, image_id, host_name)
    temp_config = template_config(name, image_id, host_name)

    b64_config = encode_b64(temp_config)

    # TODO handle bad response
    resp = execute("onetemplate", ["create", "file_content_direct", b64_config])

    # get template id from response
    m = RE_TEMPLATE_ID.match(resp)
    if m
      m[1].to_i
    else
      Rails.logger.error("Error creating PLCloud template: #{resp}")
      Rails.logger.error("Used template config:\n#{temp_config}")
      -1
    end
  end


  # @param [Integer] template_id template id should be one from onetemplate list
  # @return [Integer] created instance id or -1 on error
  def create_instance(template_id)

    resp = execute('onetemplate', ['instantiate', template_id])

    # get instance ID
    m = RE_VM_ID.match(resp)
    if m
      m[1].to_i
    else
      Rails.logger.error("Error creating PLCloud instance: #{resp}")
      Rails.logger.error("Used template id: #{template_id}")
      -1
    end
  end

  private

  # @return [String] template config file
  def template_config(name, image_id, host_name, network_id=0, cpu=0.5, memory=1024, arch='x86_64')
    <<-eos
NAME = "#{name}"
CPU    = #{cpu}
MEMORY = #{memory}

DISK = [ IMAGE_ID  = #{image_id} ]

NIC    = [ NETWORK_ID = #{network_id} ]

OS = [ arch = "#{arch}" ]

CONTEXT = [
  hostname = "#{host_name}"
]
    eos
  end

  # @return [String] base64 encoded file content for send to PLCloud REST with POST
  def encode_b64(text)
    Base64.encode64(text).split("\n").join('\n')
  end

  # @return [Response] response from POST request sent by this method
  # @param [String] command command like onetemplate, onevm, oneimage, etc.
  # @param [Array<String>] args list of arguments for command, ie. "create", "file_content_direct", ...
  def execute(command, args)
    RestClient.post "#{PLCLOUD_URL}/exec/#{command}",
                    "[\"#{args.join('", "')}\"]",
                    'One-User' => @secrets.login, 'One-Secret' => @secrets.password,
                    :content_type => :json, :accept => :json
  end

end