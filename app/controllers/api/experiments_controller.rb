
class Api::ExperimentsController < Api::ApplicationController
  before_filter :load_experiment, except: [ :index ]

  def index
    experiments = @current_user.experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }.map do |ex|
      {
          name: ex.name,
          start_at: ex.start_at.strftime('%Y-%m-%d %H:%M'),
          end_at: ex.end_at.nil? ? nil : ex.end_at.strftime('%Y-%m-%d %H:%M'),
          is_running: ex.is_running,
          url: api_experiment_path(ex.id),
          owned_by_current_user: @current_user.owns?(ex),
          percentage_progress: ((ex.get_statistics[2].to_f / ex.experiment_size) * 100).to_i
      }
    end

    render json: experiments
  end

  # TODO - shared_with should be a list of urls or logins/emails
  def show
    unnecessary_keys = [ "experiment_id", "user_id", "simulation_id", "__hash_attributes", "shared_with" ]

    all, sent, done = @experiment.get_statistics

    render json: @experiment.to_h.merge({
      simulation_scenario_url: api_simulation_scenario_path(@experiment.simulation_id),
      simulations_url: api_experiment_simulations_path(@experiment.id),
      size: @experiment.experiment_size,
      all_simulations: all,
      sent_simulations: sent,
      done_simulations: done,
      percentage_progress: ((done.to_f / @experiment.experiment_size) * 100).to_i,
      owned_by_current_user: @current_user.owns?(@experiment),
      start_at: @experiment.start_at.strftime('%Y-%m-%d %H:%M'),
      end_at: @experiment.end_at.nil? ? nil : @experiment.end_at.strftime('%Y-%m-%d %H:%M'),
      progress_bar: @experiment.progress_bar_color,
      binaries_results_url: results_binaries_experiment_path(@experiment.id),
      structured_results_url: file_with_configurations_experiment_path(@experiment.id)
      # shared_with: @experiment.shared_with.map{|user_id| ScalarmUser.where(id: user_id).first }
    }).delete_if {|key, value| unnecessary_keys.include?(key) }
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

  def load_simulation
    validate(
        simulation_id: [:optional, :security_default],
        simulation_name: [:optional, :security_default]
    )

    @simulation = if params['simulation_id']
                    @current_user.simulation_scenarios.where(id: BSON::ObjectId(params['simulation_id'].to_s)).first
                  elsif params['simulation_name']
                    @current_user.simulation_scenarios.where(name: params['simulation_name'].to_s).first
                  else
                    nil
                  end

    if @simulation.nil?
      flash[:error] = t('simulation_scenarios.not_found', { id: (params['simulation_id'] or params['simulation_name']),
                        user: @current_user.login })

      respond_to do |format|
        format.html { redirect_to action: :index }
        format.json { render json: { status: 'error', reason: flash[:error] }, status: 403 }
      end
    end
  end
end
