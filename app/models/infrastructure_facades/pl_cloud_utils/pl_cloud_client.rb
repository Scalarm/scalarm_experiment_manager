require 'rest-client'

class PLCloudClient
  PLCLOUD_URL = 'https://149.156.10.32:3443'

  RE_VM_ID = /VM ID: (\d+)/

  # @param [PLCloudSecrets] secrets secrets used to authenticate to PLCloud REST service
  def initialize(secrets)
    @secrets = secrets
  end

  # @return [int] template id
  def create_teamplate(name, image_id, host_name)
    template_config = <<-eos
NAME = "#{name}"
CPU    = 0.5
MEMORY = 1024

DISK = [ IMAGE_ID  = #{image_id} ]

NIC    = [ NETWORK_ID = 0 ]

OS = [ arch = "x86_64" ]

CONTEXT = [
  hostname = "#{host_name}"
]
    eos

    b64_config = Base64.encode64(template_config).split("\n").join('\n')

    puts "using login: #{@secrets.login}"

    resp = RestClient.post "#{PLCLOUD_URL}/exec/onetemplate",
                    "[\"create\", \"file_content_direct\", \"#{b64_config}\"]",
                    'One-User' => @secrets.login, 'One-Secret' => @secrets.password,
                    :content_type => :json, :accept => :json

    m = RE_VM_ID.match(resp)

    if m
      m[1].to_i
    end
      -1
    else

  end

  def create_instance(name, image_id, host_name)
    -1 # TODO
  end

end