require 'rest-client'
require 'json'
require 'xmlsimple'

class PLCloudClient
  PLCLOUD_URL = 'https://149.156.10.32:3443'
  DNAT_URL = 'https://149.156.10.32:8401/dnat'

  RE_ID = /ID: (\d+)/
  RE_VM_ID = /VM ID: (\d+)/

  FILE_CONTENT_DIRECT = 'file_content_direct'

  # TODO: clean up default template values

  # @param [PLCloudSecrets] secrets secrets used to authenticate to PLCloud REST service
  def initialize(secrets)
    @secrets = secrets
  end

  # @param [String] name
  # @param [Integer] image_id
  # @param [Integer] count
  # @param [Hash] vm_config hash with VM template params: host_name, network_id, cpu, memory, arch
  # @return [Array<Integer>] list of PLCloud VM instances ids ([] on error)
  def create_instance(name, image_id, count,
      vm_config={host_name: name, network_id: 0, cpu: 0.5, memory: 1024, arch: 'x86_64'})

    conf = self.template_config(name, image_id, vm_config[:host_name],
                         vm_config[:network_id], vm_config[:cpu], vm_config[:memory], vm_config[:arch])

    onevm_create(conf, count)

  end

  def vm_instance(vm_id)
    PLCloudInstance(vm_id, self)
  end


  # -- PLCloud REST OpenNebula utils --

  # @return [Integer] created template id or -1 on error
  def onetemplate_create(name, image_id, host_name)
    temp_config = template_config(name, image_id, host_name)
    Rails.logger.debug("Creating PLCloud template using config: #{temp_config}")

    b64_config = encode_b64(temp_config)

    # TODO handle bad response
    resp = execute('onetemplate', ['create', 'file_content_direct', b64_config])

    # get template id from response
    m = RE_ID.match(resp)
    if m
      m[1].to_i
    else
      Rails.logger.error("Error creating PLCloud template: #{resp}")
      Rails.logger.error("Used template config:\n#{temp_config}")
      -1
    end
  end


  # @param [Integer] template_id template id should be one from onetemplate list
  # @return [Array<Integer>] created instance ids or [] on error
  def onetemplate_instantiate(template_id, count)

    Rails.logger.debug("Creating PLCloud VM instance using template id: #{template_id}")
    resp = execute('onetemplate', ['instantiate', template_id, '--multiple', count])

    # TODO: when other amount of instances than requested are created
    # get instance ID
    ids = resp.scan(RE_VM_ID)
    if ids.length > 0
      ids.map {|i| i[0].to_i}
    else
      Rails.logger.error("Error instantiating PLCloud template: #{resp}")
      Rails.logger.error("Used template id: #{template_id}")
      []
    end
  end

  # @param [String] template_conf template config file from template_config method
  # @param [Object] count
  def onevm_create(template_conf, count)
    resp = execute('onevm', ['create', FILE_CONTENT_DIRECT,
                                   encode_b64(template_conf), '--multiple', count])

    ids = resp.to_s.scan(RE_ID)
    if ids.length > 0
      ids.map {|i| i[0].to_i}
    else
      Rails.logger.error("Error creating PLCloud instance(s): #{resp}")
      Rails.logger.error("Used template config:\n#{template_conf}")
      []
    end
  end

  # @return [String] template config file
  def template_config(name, image_id, host_name=name, network_id=0, cpu=0.5, memory=1024, arch='x86_64')
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
    begin
      url = "#{PLCLOUD_URL}/exec/#{command}"
      str_args = "[\"#{args.join('", "')}\"]"

      RestClient.post url, str_args,
                      'One-User' => @secrets.login, 'One-Secret' => @secrets.password,
                      :content_type => :json, :accept => :json
    rescue
      puts "Exception: #{$!}\n#{url}, #{str_args}"
      nil
    end
  end

  # @return [Hash] {:ip => string cloud public ip, :port => string redirected port} or nil on error
  def redirect_port(vm_ip, port)
    # equivalent: oneport -a vm_ip -p port
    # ca_file = '/software/local/cloud/rest-api-client/1.0/etc/one38.crt'

    # TODO: use CA

    dnat = RestClient::Resource.new(DNAT_URL, user: @secrets.login, password: @secrets.password)
    # ssl_ca_file = path_to_ca, verify_ssl: OpenSSL::SSL::VERIFY_PEER
    payload = [{'proto' => 'tcp', 'port' => port}].to_json

    resp = dnat[vm_ip].post payload, content_type: 'text/json'

    data = JSON.parse resp

    unless data.kind_of?(Array) and data.size == 1
      Rails.logger.error "Redirection PLCloud VM port #{vm_ip}:#{port} failed. Response from server:\n#{resp}"
      return nil
    end

    dh = data[0]

    unless dh.kind_of?(Hash)
      Rails.logger.error "Redirection PLCloud VM port #{vm_ip}:#{port} failed. Response from server:\n#{resp}"
      return nil
    end

    Rails.logger.debug("Successful PLCloud VM port redirection:\n #{dh['pubIp']}:#{dh['pubPort']} -> #{dh['privIp']}:#{dh['privPort']}")

    {ip: dh['pubIp'], port: dh['pubPort']}
  end

  # @return [Hash] {<private_port_num> => {ip: <public_ip>, port: <public_port_num>}}
  # @param [String] vm_ip virtual machine's private ip
  def redirections_for(vm_ip)
    dnat = RestClient::Resource.new(DNAT_URL, user: @secrets.login, password: @secrets.password)
    resp = dnat[vm_ip].get
    data = JSON.parse resp

    Hash[data.map {|r| [r['privPort'], {ip: r['pubIp'], port: r['pubPort']}]}]
  end

  # Get VM info with "onevm show <vm_id> --xml"
  # Information can be obtained from hash converted from given XML.
  # Eg. vm_info(99)['TEMPLATE']['NIC']['IP'] gives VM's private IP address of VM with id=99.
  # @return [Hash] keys are uppercase Strings, values can be String or Hash
  # @param [Fixnum] vm_id VM's id, can be also String or other type with .to_s
  def vm_info(vm_id)
    resp = execute('onevm', ['show', vm_id.to_s, '--xml'])
    XmlSimple.xml_in(resp, 'ForceArray' => false)
  end

end