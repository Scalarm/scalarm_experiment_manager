module ApplicationHelper

  def log_bank_url(storage_manager_url, experiment)
    "https://#{storage_manager_url}/experiment/#{experiment.id}/from/1/to/#{experiment.experiment_size}"
  end

  def button_classes
    'button radius small expand last-element action-button'
  end

end
