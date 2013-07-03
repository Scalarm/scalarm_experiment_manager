# Attributes
# sm_uuid => string - uuid which identifies a simulation manager - also can be used as user
# password => password of the attached simulation manager

class SimulationManagerTempPassword < MongoActiveRecord

  def self.collection_name
    'simulation_manager_temp_passwords'
  end

  def self.create_new_password_for(sm_uuid)
    password = SecureRandom.base64
    temp_pass = SimulationManagerTempPassword.new({'sm_uuid' => sm_uuid, 'password' => password})

    temp_pass.save
    temp_pass
  end

end