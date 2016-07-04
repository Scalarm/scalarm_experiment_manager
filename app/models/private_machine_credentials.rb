# Fields:
# host: ip/dns address of the machine
# port
# user_id: ScalarmUser id who has this secrets
#
# login: ssh login
# secret_password: ssh password
#
# other fields are user defined and should be of String class to enable encryption!

require 'scalarm/database/model/private_machine_record'

class PrivateMachineCredentials < Scalarm::Database::Model::PrivateMachineCredentials
  include SSHEnabledRecord

  attr_join :user, ScalarmUser

  SSH_AUTH_METHODS = %w(password keyboard-interactive)

  def ssh_params
    { port: port.to_i, password: secret_password, auth_methods: SSH_AUTH_METHODS, timeout: 15 }
  end

  def valid?
    begin
      ssh_session do |ssh|
        discover_os_and_arch(ssh)
      end
      true
    rescue
      false
    end
  end

  def discover_os_and_arch(ssh)
    uname_output = ssh.exec!(BashCommand.new().append("uname -a").to_s)
    os_and_arch = parse_os_and_arch_string(uname_output)

    self.os = os_and_arch["os"] if os_and_arch.include?("os")
    self.arch = os_and_arch["arch"] if os_and_arch.include?("arch")
  end

  def parse_os_and_arch_string(uname_output)
    os_and_arch = {}

    uname_output.split("\n").each do |line|
      if line.include?("GNU/Linux")
        os_and_arch["os"] = "linux"

        if line.include?(" x86_64 ")
          os_and_arch["arch"] = "amd64"
        elsif line.include?(" x86 ")
          os_and_arch["arch"] = "386"
        end

        break

      elsif line.include?("Darwin")
        os_and_arch["os"] = "darwin"

        if line.include?("RELEASE_X86_64 ")
          os_and_arch["arch"] = "amd64"
        elsif line.include?("RELEASE_X86")
          os_and_arch["arch"] = "386"
        end

        break
      end
    end

    os_and_arch
  end

  def runtime_platform
    unless self.os.nil? or self.arch.nil?
      "#{self.os}_#{self.arch}"
    else
      "linux_amd64"
    end
  end

  private # -------

  def _get_ssh_session
    Net::SSH.start(host, login, ssh_params)
  end

  def _get_scp_session
    Net::SCP.start(host, login, ssh_params)
  end

end
