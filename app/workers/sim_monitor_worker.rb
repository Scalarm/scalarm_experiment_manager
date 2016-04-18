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
        logger.info "SiM: #{sim.record}"

        begin
          sim.monitor
        rescue Exception => e
          logger.error "Sim monitoring: #{sim.record} - exception in the monitor method: #{e}"
        ensure
          if not sim.state == :error
            run_another_monitoring_loop = true
          end
        end
      end
    end

    if run_another_monitoring_loop
      logger.info "Scheduling another monitoring session for infrastructure '#{infrastructure_id}'"
      SimMonitorWorker.perform_in(30.seconds, infrastructure_id, user_id)
    else
      logger.info "The end of the monitoring process for infrastructure '#{infrastructure_id}'"
    end
  end

end
