class ClustersController < ApplicationController

  def index
    clusters = ClusterRecord.all.select{|cr| cr.visible_to?(@current_user.id)}
    clusters = clusters.map{|cr|
      cr.scheduler_label = SchedulerFactory.instance.get_scheduler(cr.scheduler).long_name
      cr._id = cr._id.to_s
      cr
    }

    respond_to do |format|
      format.json { render json: clusters.to_json }
    end
  end

  def create
    validate(
        name: [:security_default],
        scheduler: [:security_default],
        host: [:security_default],
        public: [:optional, :security_default]
    )

    cluster = ClusterRecord.new({
      name: params[:name].to_s,
      scheduler: params[:scheduler].to_s,
      host: params[:host].to_s,
      public: params[:public].to_s == 'true',
      created_by: @current_user.id
    })

    cluster.shared_with = []
    cluster.save

    respond_to do |format|
      format.json { render json: cluster.to_json }
    end
  end

  def destroy
    validate(id: [:security_default])

    cluster_record = ClusterRecord.where(id: params[:id].to_s).first

    if cluster_record.nil? or not cluster_record.visible_to?(@current_user.id)
      status = :not_found
    else
      if cluster_record.destroy
        ClusterCredentials.where(cluster_id: params[:id].to_s).each(&:destroy)
        status = :ok
      else
        status = :internal_server_error
      end
    end

    respond_to do |format|
      format.json { render json: {}, status: status }
    end
  end

  def credentials
    creds = ClusterCredentials.where(owner_id: @current_user.id).map{|cr|
      cr.cluster_name = cr.cluster.name
      cr.type_label = if cr.type == "password"
                        "Username & password"
                      elsif cr.type == "privkey"
                        "Private key"
                      else
                        "Unknown type"
                      end

      cr.secret_password = nil
      cr
    }

    respond_to do |format|
      format.json { render json: creds }
    end
  end
end
