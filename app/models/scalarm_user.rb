# Attributes
# _id => auto generated user id
# dn => distinguished user name from certificate
# login => last CN attribute value from dn

require 'scalarm/service_core/scalarm_user'

##
# Scalarm::ServiceCore::User extended with experiment management methods.
class ScalarmUser < Scalarm::ServiceCore::ScalarmUser
  include PlGridUser

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

    simulation_scenarios.sort { |s1, s2|
      s2.created_at <=> s1.created_at }
  end

  def owns?(experiment)
    id == experiment.user_id
  end

  # infrastructure monitoring flags
  def monitoring_scheduled?(infrastructure_id)
    self.scheduled_monitoring ||= {}

    self.scheduled_monitoring.include?(infrastructure_id)
  end

  def set_monitoring_scheduled(infrastructure_id)
    self.scheduled_monitoring ||= {}

    self.scheduled_monitoring[infrastructure_id] = true
  end

  def unset_monitoring_scheduled(infrastructure_id)
    self.scheduled_monitoring ||= {}

    self.scheduled_monitoring.delete(infrastructure_id)
  end

end