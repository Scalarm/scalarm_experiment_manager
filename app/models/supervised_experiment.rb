require 'scalarm/service_core/token_utils'

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
# * supervised - boolean, always true, marker which allow to distinguish normal experiment from
#   supervised one [set by #initialize]
# * completed - boolean, marker which allow to check if experiment is completed
#   (which equals that supervisor script finished and sent result) [set false by #initialize,
#   modified to true by #mark_as_complete!]
# * results - hash, contains result of experiment (sent by supervisor script) [set empty by
#   initialize, modified by #mark_as_complete!]
# * supervisor_script_uuid - string, id of supervisor script, used for authentication [set by
#   #start_supervisor_script]
# * is_error - boolean, this flag is true when experiment is in error state
#   [set by ExperimentController#mark_as_complete]
# * error_reason - string, set with is_error flag is_reason [set by ExperimentController#mark_as_complete]
class SupervisedExperiment < CustomPointsExperiment

  ##
  # Sets parameters needed for SupervisorExperiment (described above), and calls super.
  # Must be call once on creation to proper initialization
  def init_empty(simulation)
    super simulation
    self.supervised = true
    self.completed = false
    self.results = {}
  end

  ##
  # Query only SupervisedExperiments from DB with additional conditions.
  def self.where(cond, opts = {})
    super({supervised: true}.merge(cond), opts)
  end

  ##
  # This method updates given supervisor script params with necessary information
  # and posts to start_supervisor_script method of Experiment Supervisor.
  #
  # @param [BSON::ObjectID] simulation_id
  # @param [String] supervisor_script_id
  # @param [Hash] script_params
  # @param [Hash] cookies - cookies Hash used to authenticate to ExperimentSupervisor
  #
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
  def start_supervisor_script(simulation_id, supervisor_script_id, script_params, scalarm_user)
    script_params['experiment_id'] = self.id.to_s
    self.supervisor_script_uuid = SecureRandom.uuid
    password = SimulationManagerTempPassword.create_new_password_for self.supervisor_script_uuid, self.id
    script_params['user'] = self.supervisor_script_uuid
    script_params['password'] = password.password

    script_params['parameters'] = []


    Simulation.find_by_id(simulation_id).input_specification.each do |category|
      category['entities'].each do |entity|
        entity['parameters'].each do |parameter|
          param = {
            id: Experiment.parameter_uid(category, entity, parameter),
            type: parameter['type']
          }
          if %w(int float).include? parameter['type']
            param[:min] = parameter['min']
            param[:max] = parameter['max']
            param[:start_value] = (parameter['min'] + parameter['max'])/2.0
            param[:start_value] = param[:start_value].to_i if parameter['type'] == 'int'
          elsif parameter['type'] == 'string'
            param[:allowed_values] = parameter['allowed_values']
            param[:start_value] = param[:allowed_values].first
          end
          script_params['parameters'].append param
        end
      end
    end


    res = nil
    begin
      # TODO: this may be slow - cache ES url
      supervisor_url = self.class.get_private_supervisor_url
      raise 'No supervisor url can be obtained from IS' if supervisor_url.blank?
      res = scalarm_user.post_with_token(
          "https://#{supervisor_url}/supervisor_runs",
          {
              supervisor_id: supervisor_script_id,
              config: script_params.to_json
          }
      )
      res = Utils::parse_json_if_string res
    rescue RestClient::Exception, StandardError => e
      Rails.logger.debug "Exception on starting supervised experiment: #{e.to_s}\n#{e.backtrace.join("\n")}"
      res = {'status' => 'error', 'reason' => e.to_s}
    end
    res
  end

  # TODO: use general sample public url method, now in applications controller
  def self.get_private_supervisor_url
    InformationService.instance.sample_public_url('experiment_supervisors')
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
  # Was this experiment marked as complete?
  #
  # Returns:
  # * true when experiment is completed, false otherwise
  def completed?
    self.completed
  end

end