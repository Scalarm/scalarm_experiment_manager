class DummyFacade < InfrastructureFacade
  def long_name
    'Dummy'
  end

  def short_name
    'dummy'
  end

  def start_simulation_managers(user_id, instances_count, experiment_id, additional_params = {})
    require 'securerandom'
    (1..instances_count).map do
      record = DummyRecord.new({
        res_name: SecureRandom.hex(8),
        user_id: user_id,
        experiment_id: experiment_id,
        sm_uuid: SecureRandom.uuid,
        time_limit: additional_params['time_limit'].to_i
      })
      record.initialize_fields
      record.save

      record
    end
  end

  # See: {InfrastructureFacade#query_simulation_manager_records}
  def query_simulation_manager_records(user_id, experiment_id, params)
    DummyRecord.where(
        user_id: user_id,
        experiment_id: experiment_id,
        time_limit: params['time_limit'].to_i
    )
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

  def _get_sm_records(query, params={})
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
    :available
  end

  def _simulation_manager_running?(record)
    true
  end

  def _simulation_manager_get_log(record)
    'Dummy log'
  end

  def _simulation_manager_prepare_resource(record)
    logger.info 'Preparing resource'
  end

  def _simulation_manager_install(record)
    logger.info "Installing SM: #{record.resource_id}"
  end

  def enabled_for_user?(user_id)
    true
  end

end