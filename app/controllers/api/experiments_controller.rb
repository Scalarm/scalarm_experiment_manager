require "#{Rails.root}/app/concepts/experiments/experiment_representer.rb"

class Api::ExperimentsController < Api::ApplicationController
  before_filter :load_experiment, except: [ :index ]

  def index
    render json: @current_user.experiments.sort{ |e1, e2| e2.start_at <=> e1.start_at }.map{|e|
             ExperimentRepresenter.new(e, @current_user, :short).to_h
           }
  end

  def show
    render json: ExperimentRepresenter.new(@experiment, @current_user).to_json
  end

  private

  def load_experiment
    validate(
        id: [:optional, :security_default]
    )

    @experiment = nil

    if params.include?(:id)
      experiment_id = BSON::ObjectId(params[:id].to_s)

      if not @current_user.nil?
        @experiment = @current_user.experiments.where(id: experiment_id).first

        if @experiment.nil?
          render nothing: true, status: :not_found
          return
        end

      elsif (not @sm_user.nil?)
        @experiment = @sm_user.scalarm_user.experiments.where(id: experiment_id).first

        if @experiment.nil?
          Rails.logger.error(t('security.sim_authorization_error', sm_uuid: @sm_user.sm_uuid, experiment_id: params[:id]))

          render nothing: true, status: :forbidden
          return
        end
      end
    end

    render nothing: true, status: :bad_request if @experiment.nil?
  end

end
