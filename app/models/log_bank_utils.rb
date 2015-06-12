module LogBankUtils
  def self.log_bank_url_base(storage_manager_url, experiment_id)
    protocol = Rails.application.secrets[:storage_manager_development] ? 'http' : 'https'
    "#{protocol}://#{storage_manager_url}/experiments/#{experiment_id}"
  end

  def self.add_token(url, scalarm_user=nil)
    scalarm_user ? "#{url}?token=#{scalarm_user.generate_token}" : url
  end

  def self.experiment_url(storage_manager_url, experiment_id, scalarm_user=nil)
    add_token(log_bank_url_base(storage_manager_url, experiment_id), scalarm_user)
  end

  def self.simulation_run_binaries_url(storage_manager_url, experiment_id, simulation_id, scalarm_user=nil)
    add_token("#{log_bank_url_base(storage_manager_url, experiment_id)}/simulations/#{simulation_id}", scalarm_user)
  end

  def self.simulation_run_stdout_url(storage_manager_url, experiment, simulation_id, scalarm_user=nil)
    add_token("#{simulation_run_binaries_url(storage_manager_url, experiment, simulation_id)}/stdout", scalarm_user)
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