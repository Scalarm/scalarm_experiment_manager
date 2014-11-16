require_relative 'sim_utils'

class StorageManager
  BOUNDARY = 'AaB03xZZZZZZ11322321111XSDW'

  def initialize(url, config)
    @address = url
    @user = config['experiment_manager_user']
    @pass = config['experiment_manager_pass']
    @development = config.include?('development')
  end

  def upload_binary_output(experiment_id, simulation_id, path_to_binaries)
    protocol = @development ? 'http' : 'https'

    url = "#{protocol}://#{@address}/experiments/#{experiment_id}/simulations/#{simulation_id}"
    cmd = <<-eos
      curl -X PUT -u #{@user}:#{@pass} --insecure -3 "#{url}" -F "file=@#{path_to_binaries}"
    eos
    puts cmd

    %x[#{cmd}]
  end

  def upload_stdout(experiment_id, simulation_id, file_path)
    protocol = @development ? 'http' : 'https'

    url = "#{protocol}://#{@address}/experiments/#{experiment_id}/simulations/#{simulation_id}/stdout"
    cmd = <<-eos
      curl -X PUT -u #{@user}:#{@pass} --insecure -3 "#{url}" -F "file=@#{file_path}"
    eos
    puts cmd

    %x[#{cmd}]
  end


end