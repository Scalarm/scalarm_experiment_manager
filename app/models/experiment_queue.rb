class ExperimentQueue < ActiveRecord::Base
  belongs_to :experiment
  
  def self.enqueue_exp_id
    begin
      exp = ExperimentQueue.order('created_at').first
      exp_id = exp.experiment_id
      exp.destroy
      
      exp_id
    rescue
      running_exps = DataFarmingExperiment.find_all_by_is_running(true)
      
      if not running_exps.empty?
        running_exps.shuffle.each do |experiment|
          if (experiment.experiment_size != ExperimentInstance.count_with_query(experiment.experiment_id, {})) or
            (ExperimentInstance.count_with_query(experiment.experiment_id, {'is_done' => false}) > 0)
            
            return experiment.experiment_id
          end
        end
      end
      
      nil
    end
  end
end
