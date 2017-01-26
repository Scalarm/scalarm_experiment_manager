class Information::ChartService
  include Mongoid::Document
  extend Information::ScalarmService

  field :address, type: String
end