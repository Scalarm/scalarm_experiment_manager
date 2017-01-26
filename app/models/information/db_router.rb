class Information::DbRouter
  include Mongoid::Document
  extend ScalarmService

  field :address, type: String
end