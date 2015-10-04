
class Api::ExperimentsController < Api::ApplicationController

  def index
    experiments = @current_user.experiments.sort { |e1, e2| e2.start_at <=> e1.start_at }.map do |ex|
      {
          name: ex.name,
          start_at: ex.start_at,
          end_at: ex.end_at,
          is_running: ex.is_running,
          location: experiment_path(ex.id)
      }
    end

    render json: experiments
  end

end
