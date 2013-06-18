require "digest/sha2"

class User < ActiveRecord::Base
  validates_uniqueness_of :username
  has_many :experiments
  has_one :grid_credentials

  def password=(pass)
    salt = [Array.new(6){rand(256).chr}.join].pack("m").chomp
    self.password_salt, self.password_hash = salt, Digest::SHA256.hexdigest(pass + salt)
  end

  def self.authenticate(username, password)
    user = User.find_by_username(username)
    if user.blank? || Digest::SHA256.hexdigest(password + user.password_salt) != user.password_hash
      raise "Bad login or password"
    end

    user
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
