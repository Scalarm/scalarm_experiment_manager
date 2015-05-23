require 'json'

module Utils
  def self.load_config
    # moved to secrets.yml
    # config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))

    Rails.application.secrets
  end

  # Used in controller methods, where parameter can be either a string or a uploaded file
  def self.read_if_file(parameter)
    parameter.kind_of?(ActionDispatch::Http::UploadedFile) ? parameter.read : parameter
  end

  def self.parse_json_if_string(value)
    value.kind_of?(String) and JSON.parse(value) or value
  end

  def self.to_bson_if_string(object_id)
    object_id.kind_of?(String) ? BSON::ObjectId(object_id) : object_id
  end

  def self.get_validation_regexp(mode)
    case mode
      when :default
        /\A(\w|-)*\z/

      when :openid_id
        /\A(\w|-|\.|:|\/|=|\?)*\z/

      when :json
        /\A(\w|[{}\[\]":\-=\. ]|,|">|"<)*\z/

      when :filename
        /\A(\w|-|\.)+\z/

      else
        /\A\z/
    end
  end

end