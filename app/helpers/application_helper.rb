module ApplicationHelper

  def log_bank_url(storage_manager_url, experiment)
    if Rails.application.secrets.include?(:storage_manager_development)
      "http://#{storage_manager_url}/experiments/#{experiment.id}"
    else
      "https://#{storage_manager_url}/experiments/#{experiment.id}"
    end
  end

  def log_bank_experiment_size_url(storage_manager_url, experiment)
    "#{log_bank_url(storage_manager_url, experiment)}/size"
  end

  def log_bank_simulation_binaries_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_url(storage_manager_url, experiment)}/simulations/#{simulation_id}"
  end

  def log_bank_simulation_binaries_size_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_simulation_binaries_url(storage_manager_url, experiment, simulation_id)}/size"
  end

  def log_bank_simulation_stdout_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_simulation_binaries_url(storage_manager_url, experiment, simulation_id)}/stdout"
  end

  def log_bank_simulation_stdout_size_url(storage_manager_url, experiment, simulation_id)
    "#{log_bank_simulation_stdout_size_url(storage_manager_url, experiment, simulation_id)}_size"
  end

  def button_classes
    'button radius small expand action-button'
  end

end
