class Information::DbInstance
  include Mongoid::Document

  field :address, type: String
end
