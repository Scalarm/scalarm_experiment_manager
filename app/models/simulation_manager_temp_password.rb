# Attributes
# sm_uuid => string - uuid which identifies a simulation manager - also can be used as user
# password => password of the attached simulation manager
# experiment_id => id of an experiment which should be calculated by Simulation Manager with this temp password

require 'scalarm/database/model/simulation_manager_temp_password'

class SimulationManagerTempPassword < Scalarm::Database::Model::SimulationManagerTempPassword
  attr_join :experiment, Experiment

  def scalarm_user
    if self.user_id.nil?

      if self.experiment_id.nil?
        nil
      else
        ScalarmUser.find_by_id(Experiment.find_by_id(self.experiment_id).user_id)
      end

    else
      ScalarmUser.find_by_id(self.user_id)
    end
  end
end