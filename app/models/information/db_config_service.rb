class Information::DbConfigService
  include Mongoid::Document

  field :address, type: String
end