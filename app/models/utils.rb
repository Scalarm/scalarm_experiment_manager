require 'json'

module Utils
  def self.load_config
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
  end

  # Used in controller methods, where parameter can be either a string or a uploaded file
  def self.read_if_file(parameter)
    parameter.kind_of?(ActionDispatch::Http::UploadedFile) ? parameter.read : parameter
  end

  def self.parse_json_if_string(value)
    value.kind_of?(String) and JSON.parse(value) or value
  end
end