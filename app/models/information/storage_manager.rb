class Information::StorageManager
  include Mongoid::Document

  field :address, type: String
end
