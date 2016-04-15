class SimMonitorWorker
  include Sidekiq::Worker

  def perform(infrastructure_id, sim_id)
    facade = InfrastructureFacadeFactory.get_facade_for(infrastructure_id)

    if facade.nil?
      puts "Couldn't create infrastructure facade for '#{infrastructure_id}'"
      return
    end

    puts "Facade: #{facade}"

    sim_record = facade.get_sm_record_by_id(sim_id)

    if sim_record.nil?
      puts "Couldn't get sim record for for '#{sim_id}' and infrastructure '#{infrastructure_id}'"
      return
    end

    puts "Record: #{sim_record}"

    sim = SimulationManager.new(sim_record, facade)
    puts "SiM: #{sim}"

    begin
      sim.monitor
    rescue Exception => e
      puts "An exception occured: #{e}"
    ensure
      if not sim.state == :error
        puts "We are going to schedule another monitoring session for '#{sim_id}' and infrastructure '#{infrastructure_id}'"
        SimMonitorWorker.perform_in(30.seconds, infrastructure_id, sim_id)
      else
        puts "This is the end of the monitoring process"
      end
    end
  end

end
