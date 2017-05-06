class SimMonitorWorker
  include Sidekiq::Worker

  def perform(infrastructure_id, user_id)
    facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_id)

    if facade.nil?
      logger.error "Couldn't create infrastructure facade for '#{infrastructure_id}'"
      return
    end

    logger.info "Infrastructure facade: #{facade.long_name}"

    run_another_monitoring_loop = false

    facade.yield_simulation_managers(user_id) do |sims|
      sims.each do |sim|
        logger.debug "SiM: #{sim.record}"

        begin
          sim.monitor
        rescue => e
          logger.error "Sim monitoring: #{sim.record} - exception in the monitor method: #{e}"
        ensure
          if not sim.state == :error
            run_another_monitoring_loop = true
          end
        end
      end
    end

    if run_another_monitoring_loop
      logger.info "Checking if scheduling another monitoring session for infrastructure '#{infrastructure_id}' is needed"
      SchedulingInfrastructureMonitoringService.new(infrastructure_id, user_id, 30.seconds).run
    else
      UnsetSchedulingInfrastructureMonitoringService.new(infrastructure_id, user_id).run
      logger.info "The end of the monitoring process for infrastructure '#{infrastructure_id}'"
    end
  end

end
