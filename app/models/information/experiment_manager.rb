class Information::ExperimentManager
  include Mongoid::Document
  extend Information::ScalarmService

  field :address, type: String
end