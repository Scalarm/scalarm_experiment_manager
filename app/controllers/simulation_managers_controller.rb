class SimulationManagersController < ApplicationController

  def index
    infrastructure_facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure])
    result = { status: 'ok' }

    if infrastructure_facade.blank?
      result[:status] = 'error'
      result[:msg] = "Infrastructure 'params[:infrastructure]' is not supported"
    else
      sm_records = infrastructure_facade.get_sm_records(@current_user.id)
      result[:sm_records] = sm_records.map(&:to_json)
    end

    if result[:status] == 'ok'
      render json: result
    else
      render json: result, status: 400
    end
  end

  def show
  end

  def code
  end

  def update
  end
end
