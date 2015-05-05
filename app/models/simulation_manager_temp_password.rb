# Attributes
# sm_uuid => string - uuid which identifies a simulation manager - also can be used as user
# password => password of the attached simulation manager
# experiment_id => id of an experiment which should be calculated by Simulation Manager with this temp password

require 'scalarm/database/model/simulation_manager_temp_password'

class SimulationManagerTempPassword < Scalarm::Database::Model::SimulationManagerTempPassword
end