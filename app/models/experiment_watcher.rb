require "experiment_instance"
require "experiment"

class ExperimentWatcher
  @@watched_experiments_ids = []
  
  @@watched_new_experiments_ids = []
  @@new_experiments_watch_moments = {}

  def self.watch(experiment)
    Thread.new do
      while true do
        begin
          if (not experiment) or (not experiment.is_running)
            @@watched_experiments_ids.delete(experiment.id) if experiment
            break
          end
  
          expired_instances = ExperimentInstance.find_expired_instances(
                                experiment.id, experiment.time_constraint_in_sec)
                                
          Rails.logger.debug("Watching experiment #{experiment.id} --- Expired instances size #{expired_instances.size}")
          expired_instances.each do |instance|
            instance.to_sent = true
            instance.save
            instance.remove_from_cache
            experiment.experiment_progress_bar.update_bar_state(instance.id)
          end
        rescue Exception => e
          Rails.logger.debug("Watching experiment error: #{e}")
          break
        end

        sleep(experiment.time_constraint_in_sec)
      end
    end
  end

  def self.watch_running_experiments
    Thread.new do
      begin
        while true do
          Experiment.running_experiments.each do |experiment|
            if not @@watched_experiments_ids.include?(experiment.id)
              watch(experiment)
              @@watched_experiments_ids << experiment.id
            end
          end
  
          sleep(600)
        end
      rescue Exception => e
        Rails.logger.debug("Error in watch_running_experiments - #{e}")
      end
      
    end
    
  end
  
  def self.watch_new_experiments
    Thread.new do

      while true do
        begin
          Experiment.running_experiments.each do |experiment|
            next if @@watched_new_experiments_ids.include?(experiment.id) or @@new_experiments_watch_moments.has_key?(experiment.id) 
            
            
              instances_generated = ExperimentInstance.count_with_query(experiment.id)
              if instances_generated != experiment.experiment_size
                @@new_experiments_watch_moments[experiment.id] = Time.now
                watch_interrupted_experiment_generation(experiment)
              end
          end
        rescue Exception => e
          Rails.logger.debug("Error while watching new experiments: #{e}")  
        end

        sleep(600)
      end

    end
  end
  
  def self.watch_interrupted_experiment_generation(experiment)
  #   interval_time = 60 + 60*rand()
    
  #   Thread.new do
  #     begin
  #       instances_generated = ExperimentInstance.count_with_query(experiment.id)
        
  #       while instances_generated != experiment.experiment_size
  #         last_watch_time = @@new_experiments_watch_moments[experiment.id]
  #         current_time = Time.now
  #         Rails.logger.debug("Watching new experiment #{experiment.id} - #{last_watch_time} - #{instances_generated} - #{last_watch_time + 300 < current_time}")
  #         if last_watch_time + 300 < current_time then
  #           Rails.logger.debug("Generating instances for experiment #{experiment.id}")
  # #           start generating new instances
  #           Thread.new do
  #             experiment.generate_instance_configurations(instances_generated)
  #           end
  #         end
  #         sleep(interval_time)
          
  #         new_instances_generated = ExperimentInstance.count_with_query(experiment.id)
  #         if new_instances_generated != instances_generated
  #           @@new_experiments_watch_moments[experiment.id] = current_time  
  #           instances_generated = new_instances_generated 
  #         end
  #       end
        
  #       @@watched_new_experiments_ids << experiment.id
  #     rescue Exception => e
  #       Rails.logger.debug("Error while watching interrupted experiment generation: #{e}") 
  #     end
  #   end
  end

end
