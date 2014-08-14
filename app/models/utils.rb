module Utils
  def self.load_config
    config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))
  end
end