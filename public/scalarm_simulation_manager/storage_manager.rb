
class StorageManager
  BOUNDARY = 'AaB03xZZZZZZ11322321111XSDW'

  def initialize(config)
    @config = config['storage_manager']
  end

  def upload_binary_output(experiment_id, simulation_id, path_to_binaries)
    url = "https://#{@config['address']}/experiment/#{experiment_id}/simulation/#{simulation_id}"
    cmd = <<-eos
      curl -X PUT -u #{@config['user']}:#{@config['pass']} --insecure -3 "#{url}" -F "file=@#{path_to_binaries}"
    eos
    puts cmd

    %x[#{cmd}]
  end

end