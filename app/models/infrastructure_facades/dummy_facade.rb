class DummyFacade < InfrastructureFacade
  def long_name
    'Dummy'
  end

  def short_name
    'dummy'
  end

  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    require 'securerandom'
    (1..instances_count).each do
      record = DummyRecord.new({
        res_id: SecureRandom.hex(8),
        user_id: user_id,
        experiment_id: experiment_id,
        sm_uuid: SecureRandom.uuid,
        time_limit: additional_params['time_limit'].to_i
      })
      record.initialize_fields
      record.save
    end
    ['ok', "Scheduled #{instances_count} dummy simulation managers"]
  end

  def sm_record_class
    DummyRecord
  end

  def add_credentials(user, params, session)
    nil
  end

  def remove_credentials(record_id, user_id, params)
    nil
  end

  def get_sm_records(user_id=nil, experiment_id=nil, params={})
    query = {}
    query.merge!({user_id: user_id}) if user_id
    query.merge!({experiment_id: experiment_id}) if experiment_id

    DummyRecord.find_all_by_query(query)
  end

  def get_sm_record_by_id(record_id)
    DummyRecord.find_by_id(record_id)
  end

  def _simulation_manager_stop(record)
    logger.info "Stop: #{record.resource_id}"
  end

  def _simulation_manager_restart(record)
    logger.info "Restart: #{record.resource_id}"
  end

  def _simulation_manager_resource_status(record)
    :running
  end

  def _simulation_manager_running?(record)
    true
  end

  def _simulation_manager_get_log(record)
    'Dummy log'
  end

  def _simulation_manager_install(record)
    logger.info "Installing SM: #{record.resource_id}"
  end

  # Overrides InfrastructureFacade method
  def to_h
    {
        name: long_name,
        children:
          [{
              name: "Inner dummy",
              infrastructure_name: short_name
          }]
    }
  end

end