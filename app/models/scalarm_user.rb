# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

require 'scalarm/service_core/scalarm_user'

class ScalarmUser < Scalarm::ServiceCore::ScalarmUser

  def grid_credentials
    GridCredentials.find_by_user_id(id)
  end

  def experiments
    Experiment.visible_to(self)
  end

  def simulation_scenarios
    Simulation.visible_to(self)
  end

  def owned_experiments
    Experiment.where(user_id: id)
  end

  def get_running_experiments
    experiments.where(is_running: true)
  end

  def get_historical_experiments
    experiments.where(is_running: false)
  end

  # returns simulation scenarios owned by this user or shared with this user
  def get_simulation_scenarios
    Simulation.where({'$or' => [
                         {user_id: self.id}, {shared_with: {'$in' => [self.id]}}, {is_public: true}]}).sort { |s1, s2|
      s2.created_at <=> s1.created_at }
  end

  def owns?(experiment)
    id == experiment.user_id
  end

end