module SimulationScenariosHelper

  def share_scenario_with_users
    ScalarmUser.all.select{|u|
      u.id != @current_user.id and (@simulation_scenario.shared_with.blank? or (not @simulation_scenario.shared_with.include?(u.id)))
    }.map{ |u|
      u.login.nil? ? u.email : u.login
    }
  end

end
