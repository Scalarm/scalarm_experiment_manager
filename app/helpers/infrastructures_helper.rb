require 'infrastructure_facades/infrastructure_facade_factory'
require 'json'

module InfrastructuresHelper

  def infrastructures_list_to_select_data(infrastructures_hash)
    infrastructures_hash.map do |first|
      first[:children] = [first.clone] unless first.has_key? :children
      [
          first[:name], first[:children].map do |second|
            [second[:name], second.to_json]
          end
      ]
    end
  end

  # TODO: not effective (deserializing JSON)
  def find_infrastructures_data_value(select_data, infrastructure_name)
    select_data.each do |*, infrastructures|
      infrastructures.each do |*, value|
        return value if JSON.parse(value)['infrastructure_name'] == infrastructure_name
      end
    end
    nil
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

end
