class ConfigurationController < ApplicationController

  def managers
    response = ""
    response += ManagerInfo.all.map{|info| info.address}.join(";")

    render :inline => response
  end

  def storage_managers
      response = ""
      response += StorageManager.all.map{|info| info.address}.join(";")

      render :inline => response
    end

  def log_failure
    failure = ManagerFailureInfo.new(:when => Time.now)

    if params[:reason]
      failure.info = params[:reason]
    end

    if params[:address]
      manager = ManagerInfo.find_by_address(params[:address])
      if manager
        failure.manager_id = manager.id
      end

    end

    failure.save

    render :inline => "OK"
  end

end
