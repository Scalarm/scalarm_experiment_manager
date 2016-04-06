require 'infrastructure_facades/infrastructure_errors'
require 'scalarm/database/model'

# For model documentation see Scalarm::Database::Model::CloudVmRecord docs
class CloudVmRecord < Scalarm::Database::Model::CloudVmRecord
  include SimulationManagerRecord
  include SSHEnabledRecord

  attr_join :image_secrets, CloudImageSecrets

  SSH_AUTH_METHODS = %w(password)

  def resource_id
    self.vm_identifier
  end

  def infrastructure_name
    cloud_name
  end

  def ssh_params
    {
        port: public_ssh_port, password: image_secrets.secret_image_password,
        auth_methods: SSH_AUTH_METHODS, paranoid: false, user_known_hosts_file: %w(/dev/null),
        timeout: 30
    }
  end

  def has_ssh_address?
    (not self.public_host.blank?) and (not self.public_ssh_port.blank?)
  end

  def update_ssh_address!(vm_instance)
    psa = vm_instance.public_ssh_address
    self.public_host, self.public_ssh_port = psa[:host], psa[:port]
    self.save
  end

  def monitoring_group
    self.image_secrets_id
  end

  def validate
    raise InfrastructureErrors::NoCredentialsError if image_secrets_id.nil?
    raise InfrastructureErrors::InvalidCredentialsError if image_secrets.invalid
  end

  def has_usable_cloud_secrets?
    # TODO: this is hack - should be delegated to cloud clients,
    # TODO: but cloud clients are considered to work only on Cloud-API level
    if cloud_name == 'pl_cloud'
      cloud_secrets and cloud_secrets.login and
          (has_usable_proxy? or has_valid_password?)
    else
      true
    end
  end

  def has_usable_proxy?
    cloud_secrets.secret_proxy
  end

  def has_valid_password?
    not cloud_secrets.invalid and cloud_secrets.secret_password
  end

  def computational_resources
    instance_type
  end

  private # --------

  def _get_ssh_session
    Net::SSH.start(public_host, image_secrets.image_login, ssh_params)
  end

  def _get_scp_session
    Net::SCP.start(public_host, image_secrets.image_login, ssh_params)
  end

end