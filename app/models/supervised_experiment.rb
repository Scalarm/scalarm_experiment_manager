##
# This class represents an instance of supervised experiment.
# SupervisedExperiment is a subclass of CustomPointsExperiment, with is subclass
# of Experiment. The main difference from normal experiment is that in case of
# supervised experiment scheduling of new simulation is external action performed
# by supervisor script maintaining by experiment supervisor. This type of experiment
# have also result, which is result of script that supervisors this experiment e.g.
# some value or point from input space.
#
# List of possible attributes:
# * supervised - always true, marker which allow to distinguish normal experiment from
#   supervised one [sets by #initialize]
# * completed - boolean, marker which allow to check if experiment is completed
#   (which equals that supervisor script finished and sent result) [sets false by #initialize,
#   modified to true by #mark_as_complete!]
# * results - contains result of experiment (sent by supervisor script) [sets empty by
#   initialize, modified by #mark_as_complete!]
# * supervisor_script_uuid - id of supervisor script, used for authentication [sets by
#   #start_supervisor_script]
class SupervisedExperiment < CustomPointsExperiment

  ##
  # Sets parameters needed for SupervisorExperiment (described above), and calls super.
  def initialize(attributes)
    super(attributes)
    self.supervised = true
    self.completed = false
    self.results = {}
  end

  ##
  # This method updates given supervisor script params with necessary information
  # and posts to start_supervisor_script method of Experiment Supervisor.
  # Set supervisor script parameters:
  # * experiment_id - id of current experiment
  # * user - user name created by SimulationManagerTempPassword
  # * password - password created by SimulationManagerTempPassword
  # * lower_limit - input space lower limits parsed from simulation input specification
  # * upper_limit - input space upper limits parsed from simulation input specification
  # * parameters_ids - input space parameter ids parsed from simulation input specification
  # * start_point - start point of supervisor script (for each parameter
  #   (lower_limit + upper_limit)/2 ) [note - string params are not supported]
  #
  # Required params:
  # * simulation_id - id of simulation used by current experiment
  # * supervisor_script_id - id of supervisor script to be used
  # * script_params - parameters for supervisor script
  # Return value:
  # * Response from Experiment Supervisor in hash with given format:
  #   * status - 'ok' or 'error' - informs if action was performed successfully
  #   * pid - only when status is 'ok' - pid of supervisor script
  #   * reason - only when status is 'error' - reason of failure to start supervisor script
  def start_supervisor_script(simulation_id, supervisor_script_id, script_params)
    script_params['experiment_id'] = self.id.to_s
    self.supervisor_script_uuid = SecureRandom.uuid
    password = SimulationManagerTempPassword.create_new_password_for self.supervisor_script_uuid, self.id
    script_params['user'] = self.supervisor_script_uuid
    script_params['password'] = password.password

    script_params['lower_limit'] = []
    script_params['upper_limit'] = []
    script_params['parameters_ids'] = []

    Simulation.find_by_id(simulation_id).input_specification.each do |category|
      category['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          script_params['lower_limit'].append parameter['min']
          script_params['upper_limit'].append parameter['max']
          script_params['parameters_ids'].append Experiment.parameter_uid(category, entity, parameter)
        end
      end
    end
    if script_params['start_point'].nil?
      script_params['start_point'] = []
      script_params['lower_limit'].zip(script_params['upper_limit']).each do |e|
        # TODO string params
        script_params['start_point'].append((e[0]+e[1])/2)
      end
    end

    res = nil
    begin
      res = RestClient.post( 'http://localhost:13337/start_supervisor_script',  script_id: supervisor_script_id,
                                                                          config: script_params.to_json)
      res = Utils::parse_json_if_string res
    rescue RestClient::Exception, StandardError => e
      Rails.logger.debug e.to_s
      res = {'status' => 'error', 'reason' => e.to_s}
    end
    res
  end

  ##
  # This method marks experiment as complete by changing completed flag to true and
  # sets results to given value
  #
  # Required params:
  # * results - json with result of experiment
  def mark_as_complete!(results)
    self.results = results
    self.completed = true
    # TODO cleanup and destroy temp password
  end

  ##
  # By calling this method one can determinate whether experiment is completed
  #
  # Returns:
  # * true when experiment is completed, false otherwise
  def completed?
    self.completed
  end

end