module WorkersScaling
  class Initializer
    MESSAGE_PREFIX = 'Missing workers scaling parameter'
    
    ##
    # @param user_id [BSON::ObjectId, String]
    # @param params [ActionController::Parameters]
    def initialize(user_id, params)
      Utils::raise_error_unless_has_key(params, :workers_scaling_params, MESSAGE_PREFIX.pluralize)
      @user_id = user_id
      @workers_scaling_params = Utils::parse_json_if_string(params[:workers_scaling_params]).symbolize_keys
    end

    ##
    # Validates workers scaling params
    def validate_params
      required_params = if @workers_scaling_params[:plgrid_default]
                          [:worker_time_limit]
                        else
                          [:name, :allowed_resource_configurations, :experiment_execution_time_limit]
                        end
      required_params.each do |param|
        Utils::raise_error_unless_has_key(@workers_scaling_params, param, "#{MESSAGE_PREFIX} #{param}",
                                          'workers_scaling_params')
      end
      # TODO more precise validation
    end

    ##
    # Start workers scaling for given params
    # @param experiment [Experiment]
    def start(experiment)
      planned_finish_time = Time.now + (@workers_scaling_params[:experiment_execution_time_limit] || 0).minutes

      algorithm = if @workers_scaling_params[:plgrid_default]
                    experiment.plgrid_default = true
                    WorkersScaling::AlgorithmFactory.plgrid_default(experiment.id.to_s, @user_id,
                                                                    @workers_scaling_params[:worker_time_limit])
                  else
                    allowed_infrastructures = @workers_scaling_params[:allowed_resource_configurations].map do |record|
                      {
                          resource_configuration: {name: record['name'].to_sym, params: record['params'].symbolize_keys},
                          limit: record['limit']
                      }
                    end

                    WorkersScaling::AlgorithmFactory.create_algorithm(
                        class_name: @workers_scaling_params[:name].to_sym,
                        experiment_id: experiment.id,
                        user_id: @user_id,
                        allowed_resource_configurations: allowed_infrastructures,
                        planned_finish_time: planned_finish_time,
                        last_update_time: Time.now,
                        params: @workers_scaling_params[:algorithm_params] || {}
                    )
                  end
      algorithm.save

      Thread.new do
        begin
          algorithm.initial_deployment
          algorithm.notify_execution
          LOGGER.tagged(experiment.id) { LOGGER.debug 'Initial deployment finished' }
        rescue => e
          LOGGER.tagged(experiment.id) { LOGGER.error "Exception occurred during initial deployment: #{e.to_s}\n#{e.backtrace.join("\n")}" }
          raise
        end
      end

      experiment.workers_scaling = true
      experiment.planned_finish_time = planned_finish_time
      experiment.save
    end

  end
end