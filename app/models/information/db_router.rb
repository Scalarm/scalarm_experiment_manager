class Information::DbRouter
  include Mongoid::Document

  field :address, type: String
end
