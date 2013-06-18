# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

class ScalarmUser < MongoActiveRecord

  def self.collection_name
    'scalarm_users'
  end

  def get_running_experiments
    DataFarmingExperiment.find_all_by_user_id(self.id).select do |experiment|
      experiment.is_running
    end
  end

  def get_historical_experiments
    DataFarmingExperiment.find_all_by_user_id(self.id).select do |experiment|
      experiment.is_running == false
    end
  end

  def get_simulation_scenarios
    Simulation.find_all_by_user_id(self.id)
  end

end