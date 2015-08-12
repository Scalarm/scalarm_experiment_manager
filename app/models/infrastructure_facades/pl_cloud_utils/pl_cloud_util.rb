require 'rest-client'
require 'json'
require 'xmlsimple'
require 'base64'

require_relative 'pl_cloud_util_instance'
require 'infrastructure_facades/infrastructure_errors'
require 'gsi'

class PLCloudError < StandardError; end

class PLCloudUtil
  PLCLOUD_URL = 'https://onecloud.plgrid.pl:3443'
  DNAT_URL = "#{PLCLOUD_URL}/dnat"

  RE_ID = /ID: (\d+)/
  RE_VM_ID = /VM ID: (\d+)/

  FILE_CONTENT_DIRECT = 'file_content_direct'

  # default VM template values
  DEFAULT_NETWORK_ID = 0
  DEFAULT_CPU = 0.5
  DEFAULT_MEMORY = 512
  DEFAULT_ARCH = 'x86_64'

  # @param [PLCloudSecrets] secrets secrets used to authenticate to PLCloud REST service
  def initialize(secrets)
    @secrets = secrets
  end

  # @param [String] name
  # @param [Integer] image_id
  # @param [Integer] count
  # @param [Hash] vm_config hash with VM template params: host_name, network_id, cpu, memory, arch
  # @return [Array<Integer>] list of PLCloud VM instances ids ([] on error)
  def create_instances(name, image_id, count, vm_config={
      host_name: name,
      network_id: DEFAULT_NETWORK_ID,
      cpu: DEFAULT_CPU,
      memory: DEFAULT_MEMORY,
      arch: DEFAULT_ARCH} )

    conf = self.template_config(name, image_id, vm_config[:host_name],
                         vm_config[:network_id], vm_config[:cpu], vm_config[:memory], vm_config[:arch])

    onevm_create(conf, count)
  end

  # Terminates and deletes instance - use with caution!
  # @param [Fixnum] vm_id vm's id
  def delete_instance(vm_id)
    execute('onevm', ['delete', vm_id])
  end

  def resubmit(vm_id)
    execute('onevm', ['resubmit', vm_id])
  end

  # @return [PLCloudUtilInstance] abstraction layer object used for managing and retrieving info about VM instance
  def vm_instance(vm_id)
    PLCloudUtilInstance.new(vm_id, self)
  end


  # -- PLCloud REST OpenNebula utils --

  # @return [Integer] created template id or -1 on error
  def onetemplate_create(name, image_id, host_name)
    temp_config = template_config(name, image_id, host_name)
    Rails.logger.debug("Creating PLCloud template using config: #{temp_config}")

    b64_config = encode_b64(temp_config)

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

    # get instance ID
    ids = resp.scan(RE_VM_ID)
    if ids.length > 0
      if ids.length != count
        Rails.logger.warn("Requested intantiate of #{count} PLCloud machines, but #{ids.length} was created.")
      end
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
      ids.map {|i| i[0]}
    else
      Rails.logger.error("Error creating PLCloud instance(s): #{resp}")
      Rails.logger.error("Used template config:\n#{template_conf}")
      []
    end
  end

  # @return [String] template config file
  def template_config(name, image_id, host_name=name,
      network_id=DEFAULT_NETWORK_ID, cpu=DEFAULT_CPU, memory=DEFAULT_MEMORY, arch=DEFAULT_ARCH)
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
      parsed_resp = JSON.parse(exec_post(command, args))
      status, data = parsed_resp['status'], parsed_resp['data']
      raise PLCloudError.new data if status != 0
      raise Gsi::ProxyError if data =~ /User couldn't be authenticated/
      data
    rescue Exception => e
      Rails.logger.error "Exception on executing ONE command #{command}(#{args.join(', ')}): #{e}\n#{e.backtrace.join("\n")}"
      nil
    end
  end

  def exec_post(command, args)
    url = "#{PLCLOUD_URL}/exec/#{command}"
    str_args = "[\"#{args.join('", "')}\"]"

    RestClient.post url, str_args,
                       'One-User' => @secrets.login,
                       'One-Secret' => (@secrets.secret_proxy or @secrets.secret_password),
                       :content_type => :json, :accept => :json
  end

  # @param [String] vm_ip
  # @param [Fixnum] port also can be String which can be converted to Fixnum
  # @return [Hash] {:host => string cloud public ip, :port => string redirected port} or nil on error
  def redirect_port(vm_ip, port)
    # equivalent: oneport -a vm_ip -p port
    # ca_file = '/software/local/cloud/rest-api-client/1.0/etc/one38.crt'
    # TODO: use CA, "ssl_ca_file = path_to_ca, verify_ssl: OpenSSL::SSL::VERIFY_PEER" to RestClient Resource
    begin
      resp = RestClient.post "#{DNAT_URL}/#{vm_ip}",
                             {'port' => port, 'proto' => 'tcp'}.to_json,
                             'One-User' => @secrets.login,
                             'One-Secret' => (@secrets.secret_proxy or @secrets.secret_password),
                             :content_type => :json, :accept => :json
    rescue
      raise InfrastructureErrors::CloudError.new "Exception during POST to port redirection service: #{$!}"
    end

    raise PLCloudError.new('Redirect port: 400 Bad Request') if resp =~ /400 Bad Request/

    data = JSON.parse resp

    unless data.kind_of?(Hash)
      raise InfrastructureErrors::CloudError.new "Redirection PLCloud VM port #{vm_ip}:#{port} failed. Response from server:\n#{resp}"
    end

    Rails.logger.debug("Successful PLCloud VM port redirection:\n #{data['pubIp']}:#{data['pubPort']} -> #{data['privIp']}:#{data['privPort']}")

    {host: data['pubIp'], port: data['pubPort']}
  end

  # @return [Hash] {<private_port_num> => {host: <public_ip>, port: <public_port_num>}}
  # @param [String] vm_ip virtual machine's private ip
  def redirections_for(vm_ip)
    resp = RestClient.get "#{DNAT_URL}/#{vm_ip}",
                          content_type: :json, accept: :json

    Rails.logger.info "RESPONSE: #{resp}"

    raise PLCloudError if resp =~ /400 Bad Request/

    data = JSON.parse resp

    Hash[data.map {|r| [r['privPort'], {host: r['pubIp'], port: r['pubPort']}]}]
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

  # @return [Hash] hash: vm_id => vm_info - like in vm_info(vm_id) method for every VM
  def all_vm_info
    resp = execute('onevm', %w(list --xml))
    infos = XmlSimple.xml_in(resp, 'ForceArray' => false)['VM']
    infos = [infos] unless infos.kind_of?(Array)
    return Hash[infos.map {|i| [i['ID'].to_i, i]}]
  end

  # @return [Hash] hash: image_id => parsed xml image info
  def all_images_info
    resp = execute('oneimage', %w(list --xml))
    infos = XmlSimple.xml_in(resp, 'ForceArray' => false)['IMAGE']
    infos = [infos] unless infos.kind_of?(Array)
    return Hash[infos.map {|i| [i['ID'], i]}]
  end

  # -- Proxy utils --

  def self.openid_proxy_to_cloud_proxy(proxy)
    Base64.encode64(proxy).split("\n").join('\n')
  end

  # Arguments for proxy from PL-Grid OpenID: proxy cert, user cert
  # def self.certs_to_pl_cloud_secret_proxy(*certs)
  #   (certs.map {|cert_txt| Base64.encode64(cert_txt.gsub('<br>', "\n")).gsub("\n", '\n')}).join('|')
  # end

end