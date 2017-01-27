require 'zip'
require 'yaml'

require 'scalarm/database/core/mongo_active_record'
require 'scalarm/service_core/utils'

class Storage::LogBankController < ApplicationController
  before_filter :authenticate, except: [
                                 :status, :get_simulation_output_size,
                                 :get_experiment_output_size, :get_simulation_stdout_size
                             ]

  before_filter :load_log_bank, except: [ :status ]
  before_filter :authorize_get, only: [ :get_simulation_output, :get_experiment_output, :get_simulation_stdout ]
  before_filter :authorize_put, only: [ :put_simulation_output, :put_simulation_stdout ]
  before_filter :authorize_delete, only: [ :delete_simulation_output, :delete_experiment_output, :delete_simulation_stdout ]

  @@experiment_size_threshold = 1024*1024*1024*300 # 300 MB

  def status
    tests = Scalarm::ServiceCore::Utils.parse_json_if_string(params[:tests])

    status = 'ok'
    message = ''

    unless tests.nil?
      failed_tests = tests.select { |t_name| not send("status_test_#{t_name}") }

      unless failed_tests.empty?
        status = 'failed'
        message = "Failed tests: #{failed_tests.join(', ')}"
      end
    end

    http_status = (status == 'ok' ? :ok : :internal_server_error)

    respond_to do |format|
      format.html do
        render text: message, status: http_status
      end
      format.json do
        render json: {status: status, message: message}, status: http_status
      end
    end
  end

  def get_simulation_output
    # just stream previously save binary data from the backend using included module
    sim_record = SimulationOutputRecord.where(
        experiment_id: @experiment_id,
        simulation_idx: @simulation_idx,
        type: 'binary'
    ).first
    file_object = sim_record.nil? ? nil : sim_record.file_object

    if file_object.nil?
      render inline: 'Required file not found', status: 404
    else
      file_name = "experiment_#{@experiment_id}_simulation_#{@simulation_idx}.tar.gz"
      response.headers['Content-Type'] = 'Application/octet-stream'
      response.headers['Content-Disposition'] = 'attachment; filename="' + file_name + '"'

      response.stream.write file_object
      response.stream.close
    end

  end

  def get_simulation_output_size
    sim_record = SimulationOutputRecord.where(experiment_id: @experiment_id, simulation_idx: @simulation_idx, type: 'binary').first
    file_data = sim_record.nil? ? nil : sim_record.file_object

    if sim_record.nil? or (sim_record.file_size.nil? and file_data.nil?)
      render inline: 'Required file not found', status: 404
    else
      render json: { size: sim_record.file_size || file_data.size }
    end
  end

  ##
  # PUT, parameters: file - binary simulation output
  def put_simulation_output
    unless params[:file] && (tmpfile = params[:file])
      render inline: 'No file provided', status: 400
    else
      sim_record = SimulationOutputRecord.new(
          experiment_id: @experiment_id,
          simulation_idx: @simulation_idx,
          type: 'binary'
      )
      sim_record.set_file_object(tmpfile)

      sim_record.save

      render inline: 'Upload completed'
    end
  end

  def delete_simulation_output
    SimulationOutputRecord.where(experiment_id: @experiment_id, simulation_idx: @simulation_idx, type: 'binary').first.destroy

    render inline: 'Delete completed'
  end

  def get_experiment_output
    output_size = 0

    SimulationOutputRecord.where(experiment_id: @experiment_id).each do |simulation_doc|
      if simulation_doc.include?('file_size')
        output_size += simulation_doc['file_size']
      else
        if not simulation_doc.file_object.nil?
          output_size += simulation_doc.file_object.size
        end
      end
    end

    if output_size > @@experiment_size_threshold
      render inline: "Experiment size: #{output_size / (1024**3)} [MB] - it is too large. Please, download subsequent simulation results manually", status: 406
    else
      t = Tempfile.new("experiment_#{@experiment_id}")

      begin
        # Give the path of the temp file to the zip outputstream, it won't try to open it as an archive.
        Zip::ZipOutputStream.open(t.path) do |zos|
          SimulationOutputRecord.where(experiment_id: @experiment_id).each do |sim_record|
            file_object = sim_record.file_object

            unless file_object.nil? or sim_record.file_object_name.nil?
              # Create a new entry with some arbitrary name
              zos.put_next_entry("experiment_#{@experiment_id}/#{sim_record.file_object_name}")
              # Add the contents of the file, don't read the stuff likewise if its binary, instead use direct IO
              zos.print file_object.force_encoding('UTF-8')
            end
          end
        end

        # End of the block  automatically closes the file.
        # Send it using the right mime type, with a download window and some nice file name.
        send_file t.path, type: 'application/zip',
                  disposition: 'attachment',
                  filename: "experiment_#{@experiment_id}.zip"

      ensure
        # The temp file will be deleted some time...
        t.close
      end
    end

  end

  def get_experiment_output_size
    output_size = 0

    SimulationOutputRecord.where(experiment_id: @experiment_id).each do |sor|
      output_size += if sor.file_size
                       sor.file_size
                     elsif sor.file_object
                       sor.file_object.size
                     else
                       0
                    end
    end

    render json: { size: output_size }
  end

  def delete_experiment_output
    SimulationOutputRecord.where(experiment_id: @experiment_id).each do |doc|
      doc.destroy
    end

    render inline: 'DELETE experiment action completed'
  end

  def get_simulation_stdout
    sim_record = SimulationOutputRecord.where(experiment_id: @experiment_id, simulation_idx: @simulation_idx, type: 'stdout').first
    file_data = sim_record.nil? ? nil : sim_record.file_object

    if file_data.nil?
      render inline: 'Required file not found', status: 404
    else
      file_name = "experiment_#{@experiment_id}_simulation_#{@simulation_idx}_stdout.txt"
      response.headers['Content-Type'] = 'text/plain'
      response.headers['Content-Disposition'] = 'attachment; filename="' + file_name + '"'

      response.stream.write file_data
      response.stream.close
    end

  end

  def get_simulation_stdout_size
    sim_record = SimulationOutputRecord.where(experiment_id: @experiment_id, simulation_idx: @simulation_idx, type: 'stdout').first
    file_data = sim_record.nil? ? nil : sim_record.file_object

    if sim_record.nil? or (sim_record.file_size.nil? and file_data.nil?)
      render inline: 'Required file not found', status: 404
    else
      render json: { size: sim_record.file_size || file_data.size }
    end
  end

  def put_simulation_stdout
    unless params[:file] && (tmpfile = params[:file])
      render inline: 'No file provided', status: 400
    else
      sim_record = SimulationOutputRecord.new(
          experiment_id: @experiment_id,
          simulation_idx: @simulation_idx,
          type: 'stdout'
      )
      sim_record.set_file_object(tmpfile)

      sim_record.save

      render inline: 'Upload completed'
    end
  end

  def delete_simulation_stdout
    SimulationOutputRecord.where(
        experiment_id: @experiment_id,
        simulation_idx: @simulation_idx,
        type: 'stdout'
    ).first.destroy

    render inline: 'Delete completed'
  end


  private

  def load_log_bank
    @experiment_id = params[:experiment_id]
    @simulation_idx = params[:simulation_id]
  end

  ##
  # Only the experiment owner or a person mentioned on the shared with experiment
  # can get output
  def authorize_get
    if @experiment_id.nil? or (@current_user.nil? and @sm_user.nil?)
      render inline: '', status: 404
      return 
    end
      
    experiment = Experiment.find_by_id(@experiment_id)
    unless experiment.owned_by?(@current_user) or experiment.shared_with?(@current_user)
      render inline: '', status: 403
    end
  end

  ##
  # All types of Scalarm users (the owner, a user on the shared with list,
  # and the Simulation Manager can put data)
  def authorize_put
    if @experiment_id.nil? or (@current_user.nil? and @sm_user.nil?)
      Rails.logger.debug('Missing experiment_id or user is not authenticated')
      render inline: '', status: 404
      return 
    end

    experiment = Experiment.find_by_id(@experiment_id)

    if not @current_user.nil?

      unless experiment.owned_by?(@current_user) or experiment.shared_with?(@current_user)
        render inline: 'This client does not have permission access this experiment',
               status: 403
      end

    elsif not @sm_user.nil?
      Rails.logger.debug('We are on the right track')

      # check if sm_user is allowed to execute experiment
      unless @sm_user.experiment_id.to_s == experiment.id.to_s
        Rails.logger.warn('This client cannot put files for this experiment')
        render inline: 'This client does not have permission to put files for this experiment',
               status: 403
      end

    else

      render inline: 'Cannot authenticate client', status: 403

    end
  end

  # only the experiment owner can delete data
  def authorize_delete
    if @experiment_id.nil? or (@current_user.nil? and @sm_user.nil?)
      render inline: '', status: 404
      return
    end
      
    experiment = Experiment.find_by_id(@experiment_id)

    if not @current_user.nil?

      unless experiment.owned_by?(@current_user) or experiment.shared_with?(@current_user)
        render inline: 'This client does not have permission access this experiment', status: 403
      end

    elsif not @sm_user.nil?

      unless @sm_user.experiment_id.to_s == experiment.id.to_s
        render inline: 'This client does not have permission access this experiment', status: 403
      end

    else
      render inline: 'Cannot authenticate client', status: 403
    end
  end

  # --- Status tests ---

  def status_test_database
    Scalarm::Database::MongoActiveRecord.available?
  end

end
