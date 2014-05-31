require 'infrastructure_facades/infrastructure_facade_factory'
require 'json'

module InfrastructuresHelper

  # Changes hash-data from InfrastrctureController.list to data for selector with groups
  def infrastructures_list_to_select_data(infrastructures_hash)
    disabled_keys = []
    data = infrastructures_hash.map do |first|
      first[:children] = [first.clone] unless first.has_key? :children
      [
          first[:name], first[:children].map do |second|
            key = second[:infrastructure_name]
            if second[:enabled] == false
              disabled_keys << key
            end
            [second[:name], key]
          end
      ]
    end

    {data: data, disabled: disabled_keys}
  end

  def image_secrets_select_data(user_id, cloud_name)
    CloudImageSecrets.find_all_by_query(user_id: user_id, cloud_name: cloud_name).map do |i|
      ["#{i.image_id} #{i.label ? i.label : ''} (#{i.image_login})", i.id]
    end
  end

  def instance_types_select_data(cloud_client)
    cloud_client.instance_types.map{|k, desc| [desc, k]}
  end

  def private_machine_credentials_select_data(user_id)
    PrivateMachineCredentials.find_all_by_user_id(user_id).map{|mach| [mach.machine_desc, mach.id]}
  end

  def infrastructure_long_name(infrastructure_name)
    InfrastructureFacadeFactory.get_facade_for(infrastructure_name).long_name
  end

  def count_simulation_managers(infrastructure_name, user_id)
    InfrastructureFacadeFactory.get_facade_for(infrastructure_name).count_sm_records(user_id)
  end

  def experiments_select_data(user)
    shared_prefix = "[#{I18n.t('infrastructure.information.shared_experiment')}] "
    user.get_running_experiments.map do |exp|
      ["#{user.owns?(exp) ? '' : shared_prefix}#{exp.name} (#{exp.id})", exp.id]
    end
  end

end
