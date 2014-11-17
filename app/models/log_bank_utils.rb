module LogBankUtils
  def self.log_bank_url_base(storage_manager_url, experiment_id)
    protocol = Rails.application.secrets.include?(:storage_manager_development) ? 'http' : 'https'
    "#{protocol}://#{storage_manager_url}/experiments/#{experiment_id}"
  end

  def self.add_token(url, user_session=nil)
    user_session ? "#{url}?token=#{user_session.generate_token}" : url
  end

  def self.experiment_url(storage_manager_url, experiment_id, user_session=nil)
    add_token(log_bank_url_base(storage_manager_url, experiment_id), user_session)
  end

  def self.simulation_run_binaries_url(storage_manager_url, experiment_id, simulation_id, user_session=nil)
    add_token("#{log_bank_url_base(storage_manager_url, experiment_id)}/simulations/#{simulation_id}", user_session)
  end

  def self.simulation_run_stdout_url(storage_manager_url, experiment, simulation_id, user_session=nil)
    add_token("#{simulation_run_binaries_url(storage_manager_url, experiment, simulation_id)}/stdout", user_session)
  end

  # These StorageManager LogBankController methods don't require authorization:
  # :get_simulation_output_size, :get_experiment_output_size, :get_simulation_stdout_size
  # so they don't need token passing

  def self.log_bank_experiment_size_url(storage_manager_url, experiment)
    "#{log_bank_url_base(storage_manager_url, experiment)}/size"
  end

  def self.simulation_binaries_size_url(storage_manager_url, experiment_id, simulation_id)
    "#{simulation_run_binaries_url(storage_manager_url, experiment_id, simulation_id)}/size"
  end

  def self.simulation_run_stdout_size_url(storage_manager_url, experiment_id, simulation_id)
    "#{simulation_run_stdout_url(storage_manager_url, experiment_id, simulation_id)}_size"
  end

end