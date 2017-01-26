class Information::ExperimentSupervisor
  include Mongoid::Document
  extend Information::ScalarmService

  field :address, type: String
end