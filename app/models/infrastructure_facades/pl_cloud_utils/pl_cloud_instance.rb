class PLCloudInstance

  def initialize(vm_id, plc_client)
    @vm_id = vm_id
    @plc_client = plc_client
  end

  def status()
    # TODO: :runnning, :pending
    :running
  end

  def destroy()
    #TODO
    Rails.logger.debug('PLCloudInstance destroy not implemented yet')
    nil
  end

  def terminate()
    #TODO
    Rails.logger.debug('PLCloudInstance terminate not implemented yet')
    nil
  end

  def reboot()
    #TODO
    Rails.logger.debug('PLCloudInstance reboot not implemented yet')
    nil
  end

  def ssh_ip()
    #TODO
    nil
  end

  def ssh_port()
    #TODO
    nil
  end

  def parse_information()
    nil
  end

end