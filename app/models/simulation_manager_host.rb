require "net/http"
require "json"

class SimulationManagerHost < ActiveRecord::Base
  validates_uniqueness_of :ip

  def run
    # Rails.logger.debug("Calling action run on SimulationManagerHost on #{self.ip}:#{self.port}")
    send_request_to_remote_node_manager("start_manager")
  end

  def stop
    # Rails.logger.debug("Calling action stop on SimulationManagerHost on #{self.ip}:#{self.port}")
    send_request_to_remote_node_manager("stop_manager")
  end

  def state
    # Rails.logger.debug("Calling action stop on SimulationManagerHost on #{self.ip}:#{self.port}")
    send_request_to_remote_node_manager("stop")
  end

  def state
    state = send_request_to_remote_node_manager("manager_status")
    # Rails.logger.debug("Calling action status on SimulationManagerHost on #{self.ip}:#{self.port}")
    # Rails.logger.debug("Respond state is #{state}")

    if state and (not state.include?("not"))
      "running"
    else
      "not_running"
    end
  end

  def unregister
    # Rails.logger.debug("Calling action unregister on SimulationManagerHost on #{self.ip}:#{self.port}")
    self.destroy
  end

  def state_in_json
    {
        :obj_id => self.id,
        :ip => self.ip,
        :port => self.port,
        :state => self.state
    }.to_json
  end

  # ======================== PRIVATE METHODS ====================
  private

  def send_request_to_remote_node_manager(action)
    config = YAML::load_file File.join(Rails.root, "config", "scalarm_experiment_manager.yml")

    http = Net::HTTP.new(self.ip, self.port.to_i)
    http.read_timeout = 3600

    req = Net::HTTP::Get.new("/#{action}/simulation/1")
    req.basic_auth config["node_manager_login"], config["node_manager_password"]

    begin
      response = http.request(req)
      return response.body
    rescue Exception => e
      logger.error("Error occured during remote communication")
      logger.error(e.message)
    end

    nil
  end

end
