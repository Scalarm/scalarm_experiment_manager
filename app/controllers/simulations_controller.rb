
class SimulationsController < ApplicationController

  def index
    @simulations = Simulation.all
    @input_writers = SimulationInputWriter.all
    @executors = SimulationExecutor.all
    @output_readers = SimulationOutputReader.all
  end

  def registration

  end

  def upload_component
    if params["component_type"] == "input_writer"
      input_writer = SimulationInputWriter.new({:name => params["component_name"], :code => params["component_code"].read})
      input_writer.save
    elsif params["component_type"] == "executor"
      executor = SimulationExecutor.new({:name => params["component_name"], :code => params["component_code"].read})
      executor.save
    elsif params["component_type"] == "output_reader"
      output_reader = SimulationOutputReader.new({:name => params["component_name"], :code => params["component_code"].read})
      output_reader.save
    end

    redirect_to :action => :index
  end

  def destroy_component
    if params["component_type"] == "input_writer"
      SimulationInputWriter.find_by_id(params["component_id"]).destroy
    elsif params["component_type"] == "executor"
      SimulationExecutor.find_by_id(params["component_id"]).destroy
    elsif params["component_type"] == "output_reader"
      SimulationOutputReader.find_by_id(params["component_id"]).destroy
    end

    redirect_to :action => :index
  end

  def upload_simulation

    redirect_to :action => :index
  end

  # GET /simulations/1
  # GET /simulations/1.xml
  def show
    @simulation = Simulation.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @simulation }
    end
  end

  # GET /simulations/new
  # GET /simulations/new.xml
  def new
    @simulation = Simulation.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @simulation }
    end
  end

  # GET /simulations/1/edit
  def edit
    @simulation = Simulation.find(params[:id])
  end

  # POST /simulations
  # POST /simulations.xml
  def create
    @simulation = Simulation.new(params[:simulation])

    respond_to do |format|
      if @simulation.save
        @simulation.save_files(params[:upload]) if params[:upload]
        format.html { redirect_to(@simulation, :notice => 'Simulation was successfully created.') }
        format.xml  { render :xml => @simulation, :status => :created, :location => @simulation }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @simulation.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /simulations/1
  # PUT /simulations/1.xml
  def update
    @simulation = Simulation.find(params[:id])

    respond_to do |format|
      if @simulation.update_attributes(params[:simulation])
        @simulation.save_files(params[:upload]) if params[:upload]
        format.html { redirect_to(@simulation, :notice => 'Simulation was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @simulation.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /simulations/1
  # DELETE /simulations/1.xml
  def destroy
    @simulation = Simulation.find(params[:id])
    @simulation.delete_files
    @simulation.destroy

    respond_to do |format|
      format.html { redirect_to(simulations_url) }
      format.xml  { head :ok }
    end
  end
end
