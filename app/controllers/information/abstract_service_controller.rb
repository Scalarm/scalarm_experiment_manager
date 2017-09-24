# Methods to implement:
# - self.model_class -> return model class
# - self.service_name -> long name for response messages

class Information::AbstractServiceController < ApplicationController
  before_filter :authenticate, :except => [:list]

  def register
    address = params[:address]

    if self.class.model_class.where(address: address).to_a.blank?
      manager = self.class.model_class.new(address: address)
      manager.save

      render json: {status: 'ok', msg: "Success: '#{address}' has been registered as #{self.class.service_name}"}
    else
      render json: {status: 'error', msg: "Failure: '#{address}' is already registered as #{self.class.service_name}"}, status: 500
    end
  end

  def list
    render json: generate_address_list
  end

  def deregister
    address = params[:address]

    self.class.model_class.where(address: address).each(&:destroy)

    render json: {status: 'ok', msg: "Success: '#{address}' has been deregistered as #{self.class.service_name}"}
  end

  def generate_address_list
    self.class.model_class.all.map(&:address)
  end
end
