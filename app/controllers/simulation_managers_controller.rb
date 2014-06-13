require 'securerandom'

class SimulationManagersController < ApplicationController

  def index
    user_id = @sm_user.blank? ? @current_user.id : @sm_user.user_id
    infrastructure_facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure])
    result = { status: 'ok' }

    if infrastructure_facade.blank?
      result[:status] = 'error'
      result[:msg] = t('simulation_managers.infrastructure_not_found', infrastructure: params[:infrastructure])
    else
      sm_records = infrastructure_facade.get_sm_records(user_id)
      result[:sm_records] = sm_records.map(&:to_h)
    end

    if result[:status] == 'ok'
      render json: result
    else
      render json: result, status: 400
    end
  end

  def code
    user_id = @sm_user.blank? ? @current_user.id : @sm_user.user_id
    infrastructure_facade = InfrastructureFacadeFactory.get_facade_for(params[:infrastructure])

    if infrastructure_facade.blank?
      render inline: t('simulation_managers.infrastructure_not_found', infrastructure: params[:infrastructure]), status: 400
    else
      sm_record = infrastructure_facade.get_sm_records(user_id, nil).select{|sm| sm.id.to_s == params[:id]}.first

      if sm_record.blank? or sm_record.sm_uuid.blank?
        render inline: t('simulation_managers.not_found', id: params[:id]), status: 400
      else
        code_path = infrastructure_facade.simulation_manager_code(sm_record)

        send_file code_path, type: 'application/zip'
      end
    end

  end

  def update
  end
end
