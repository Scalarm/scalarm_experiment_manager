require 'scalarm/service_core/parameter_validation'

module AdaptersSetup
  include Scalarm::ServiceCore::ParameterValidation
  extend ActiveSupport::Concern

  def set_up_adapter_checked(simulation, adapter_type, current_user, params, mandatory = true)
    begin
      validate_params(
          params,
          {
              "#{adapter_type}_id".to_sym => [:optional, :security_default],
              "#{adapter_type}_name".to_sym => [:optional, :security_default]
          }
      )
      simulation.set_up_adapter(adapter_type, current_user, params, mandatory)
    rescue AdapterNotFoundError => e
      flash[:error] = t('simulations.create.adapter_not_found', {adapter: e.adapter_type, id: e.adapter_id})
      raise Exception.new("Setting up Simulation#{e.adapter_type} is mandatory")
    rescue SecurityError => e
      flash[:error] = e.to_s
      raise e
    rescue MissingAdapterError => e
      flash[:error] = t('simulations.create.mandatory_adapter', {adapter: e.adapter_type, id: e.adapter_id})
      raise Exception("Setting up Simulation#{e.adapter_type} is mandatory")
    end
  end

end