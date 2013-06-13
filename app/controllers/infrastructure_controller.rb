#require 'libvirt'
require 'net/ssh'
require 'net/scp'
require "aws-sdk"
require 'json'

require "grid_job"

class InfrastructureController < ApplicationController
  include ActionView::Helpers::JavaScriptHelper

  @@tamplate_dir = "/cloud_data/eusas_images/"
  @@tamplate_name = "ubuntu.img"

  before_filter :register_to_amazon, :only => [:index, :run_amazon_instances, :manage_ec2_vm, :infrastructure_info, :add_vms_to_exp]

  def index
    check_authentication
    @machines = PhysicalMachine.all
    
    logger.debug("Current user id: #{session[:user]}")
    activate_plgrid_monitoring_thread
  end

  def configure_amazon
    register_to_amazon

    redirect_to :action => "index"
  end

  def configure_plgrid
    credentials = GridCredentials.find_by_user_id(current_user.id)

    if credentials
      credentials.user_id = current_user.id
      credentials.login = params[:username]
      credentials.password = params[:password]
      credentials.host = params[:host]
    else
      credentials = GridCredentials.new({ 'user_id' => current_user.id, 'login' => params[:username], 'host' => params[:host]})
      credentials.password = params[:password]
    end

    # for temporary usage during the session
    session[:grid_credentials] = credentials

    if params[:save_settings]
      current_user.save
    end

    redirect_to action: :index
  end

  def configure_plgrid_grouping_factor
    #if params[:plgrid_grouping_factor]
    session[:plgrid_grouping_factor] = params[:plgrid_grouping_factor]
    #end

    redirect_to :action => :index
  end

  def register_simulation_manager_host
    @simulation_manager_host = SimulationManagerHost.new(params[:simulation_manager_host])
    @simulation_manager_host.save

    redirect_to :action => :index
  end

  def manage_simulation_manager_host
    @simulation_manager_host = SimulationManagerHost.find(params[:simulation_manager_host_id])
    @method = params[:method]

    @simulation_manager_host.send(@method)

    new_state = if @simulation_manager_host.nil?
                  { :obj_id => params[:simulation_manager_host_id], :ip => 0, :port => 0, :state => "destroyed" }.to_json
                else
                  @simulation_manager_host.state_in_json
                end

    respond_to do |format|
      format.js { render :inline => new_state }
    end
  end

  def register_physical_machine
    @machines = PhysicalMachine.all
    @pmachine = PhysicalMachine.new(params[:physical_machine])
    @error = nil; @notice = nil

    if PhysicalMachine.find_by_ip @pmachine.ip
      @error = "Physical machine with IP = #{@pmachine.ip} has been already registered!"
    else
      begin
        logger.info("qemu+ssh://#{@pmachine.username}@#{@pmachine.ip}/system")
        #conn = Libvirt::open("qemu+ssh://#{@pmachine.username}@#{@pmachine.ip}/system")
        #@pmachine.cpus = conn.node_get_info.cpus.to_i
        #@pmachine.cpu_model = conn.node_get_info.model
        #@pmachine.cpu_freq = conn.node_get_info.mhz
        #@pmachine.memory = conn.node_get_info.memory.to_f / 1024
        #
        #conn.list_defined_domains.each do |domain_name|
        #  domain = conn.lookup_domain_by_name domain_name
        #  vm = VirtualMachine.new(:name => domain.name,
        #                          :state => VirtualMachine.state_string(domain.info.state),
        #                          :cpus => domain.info.nr_virt_cpu,
        #                          :memory => domain.info.max_mem.to_f / 1024)
        #  @pmachine.virtual_machines << vm
        #end
        #
        #conn.list_domains.each do |domain_name|
        #  domain = conn.lookup_domain_by_id domain_name
        #  vm = VirtualMachine.new(:name => domain.name,
        #                          :state => VirtualMachine.state_string(domain.info.state),
        #                          :cpus => domain.info.nr_virt_cpu,
        #                          :memory => domain.info.max_mem.to_f / 1024)
        #  @pmachine.virtual_machines << vm
        #end

        if @pmachine.save then
          @notice = "New physical machine has been registered"
        else
          @error = "Physical machine has not been registered due to database connection issues"
        end
      rescue => e
        @error = "Physical machine has not been registered due to some errors: #{e.message}"
        begin
          Net::SSH.start(@pmachine.ip, @pmachine.username) do |ssh|
            ssh.exec!("service libvirt-bin restart")
          end

          @notice = "Libvirt daemon has been restarted. Please try to connect this host once again."
        rescue
          @error += "\n --- Could not connect to the host (#{@pmachine.username}@#{@pmachine.ip})"
        end
      end
    end
  end

  def manage_vm
    @vm = VirtualMachine.find params[:vm_id]
    @error_msg = nil

    if params[:operation] == "create" then
      host = "#{@vm.physical_machine.username}@#{@vm.physical_machine.ip}"
      cmd_ouput = %x[virsh -c qemu+ssh://#{host}/system start #{@vm.name}]
      logger.debug("Creating VM command output: #{cmd_ouput}")

      @vm.state = 'running'
      @vm.save
    else
      conn = @vm.physical_machine.get_libvirt_connection
      operation = params[:operation]
      domain = conn.lookup_domain_by_name @vm.name

      begin
        domain.send(operation.to_sym)
      rescue
        @error_msg = "Could not perform the give operation. Please try again."
      end

      @vm.state = VirtualMachine.state_string(domain.info.state)
      @vm.save
    end

    respond_to do |format|
      format.js { render :partial => "manage_vm" }
    end
  end

  def manage_ec2_vm
    @vm_id = params[:vm_id]

    if session[:aws_access_key].nil?
      @ec2_running_instances.delete(@vm_id)
      return
    end

    begin
      @vm_instance = @ec2.instances[params[:vm_id]]
      @vm_status = @vm_instance.status

      case params[:operation]
        when "run"
          @vm_instance.start

        when "stop"
          @vm_instance.stop

        when "destroy"
          @vm_instance.terminate
      end
    rescue Exception => e
      error_msg = "Error occured during updating EC2 instances - #{e.message}"
      logger.error(error_msg)
      # Socky.send("show_flash_error('#{error_msg}')", :channels => "infrastructure")
    end
  end

  def manage_pm
    pm = PhysicalMachine.find(params[:pm_id])

    remove_cmd = []
    if not pm.virtual_machines.blank?
      vm_ids = pm.virtual_machines.map { |vm| "vm-#{vm.id}" }
      vm_ids.each { |vm_id| remove_cmd << "infrastructure_tree.removeSubtree('#{vm_id}', true, 'replot', { } )" }
    end

    remove_cmd << "infrastructure_tree.removeSubtree('pm-#{pm.id}', true, 'replot', { } )"
    pm.destroy

    respond_to do |format|
      format.js {
        render :inline => remove_cmd.join(";")
      }
    end
  end

  def create_vm
    spawn do
      pm = PhysicalMachine.find_by_id params[:machine_id]
      conn = pm.get_libvirt_connection

      vm = run_vm(params[:name], params[:cpu].to_i, params[:memory].to_f, conn)

      pm.virtual_machines << vm
      pm.save

      flash[:notice] = "Virtual machine has been already created!"

      vm_json = "{ 'id': 'pm-#{pm.id}',
                     'children': [ { 'id' : 'vm-#{vm.id}',
                                     'name' : '#{escape_javascript(render_to_string :partial => "vm_node", :locals => {:vm => vm})}' } ]}"

      # Socky.send("infrastructure_tree.addSubtree(#{vm_json}, 'replot', { }); ", :channels => "infrastructure")
    end

    render :inline => "OK"
  end

  def create_several_vms
    spawn do
      number, cpus, memory = params[:number].to_i, params[:cpus].to_i, params[:memory].to_f
      lasted_vms_num = run_vms_with_reqs(number, cpus, memory)

      if lasted_vms_num > 0 then
        flash[:error] = "Couldn't start last #{lasted_vms_num} VMs due to lack of resources"
        logger.debug("Could not start last #{lasted_vms_num} virtual machines due to lack of resources")
      else
        flash[:notice] = "Virtual machines has been already created!"
      end

      #TODO should hide busy indicator of private infrastructure block
      # Socky.send("window.location.reload()", :channels => "infrastructure")
    end

    render :inline => "OK"
  end

  def destroy_vm
    vm = VirtualMachine.find_by_id(params[:vm_id])
    conn = vm.physical_machine.get_libvirt_connection
    domain = conn.lookup_domain_by_name vm.name
    if vm.state == 'running'
      domain.send(:destroy)
    end
    domain.undefine

    vm.destroy
    result = %x[rm #{@@tamplate_dir}#{vm.name}.img]
  end

  def update_vm
    @vm = VirtualMachine.find_by_id(params[:vm_id])
    respond_to do |format|
      format.js { render :partial => "manage_vm" }
    end
  end
  
  def add_hosts_to_exp
    hosts_to_run = params[:number].to_i
    
    hosts_to_run.times{ ExperimentQueue.new(:experiment_id => params[:experiment_id]).save }
    managers = SimulationManagerHost.select{|x| x.state == "not_running"}.shuffle[0...hosts_to_run].map(&:run)
    
    respond_to do |format|
      format.js{render :inline => "booster.onSuccess('hosts added');"}
    end
  end
  
  def add_jobs_to_exp
    if session[:grid_credentials] ||
        params[:job_counter].empty? || params[:time_limit].empty?

      job_counter = params[:job_counter].to_i
      # getting time limit in minutes but script accept seconds
      time_limit = params[:time_limit].to_i * 60
      credentials = session[:grid_credentials]

      upload_simulation_manager(credentials)
      job_counter.times{ ExperimentQueue.new(:experiment_id => params[:experiment_id]).save }
      run_grid_jobs(credentials, job_counter, time_limit, 1000000)
      
      msg = 'Jobs have been scheduled.'
    else
      msg = "You did not provide credentials to PL-Grid."
    end
    
    respond_to do |format|
      format.js{render :inline => "booster.onSuccess('#{msg}');"}
    end
  end

  def add_vms_to_exp
    vm_counter = params[:number].to_i
    
    msg = if defined? @ec2
      begin
        ec2_region = @ec2.regions["us-east-1"]
#         old "ami-e93b8d80"
        ec2_region.instances.create(:image_id => "ami-c9813da0",
                                               :count => vm_counter,
                                               :instance_type => params[:vm_type],
                                               :security_groups => ["quicklaunch-1"])
                     
        "Virtual Machines have been scheduled."
      rescue Exception => e
        logger.error(error_msg)
        "Error occured during updating EC2 instances - #{e.message}"
      end
    else
      "You did not provide credentials to Amazon Cloud."      
    end
    
    respond_to do |format|
      format.js{render :inline => "booster.onSuccess('#{msg}');"}
    end
  end

  # submit required number of jobs with specified time and simulation number limits to PL-Grid
  def submit_job_to_plgrid
    if session[:grid_credentials] ||
        params[:job_counter].empty? || params[:time_limit].empty? || params[:simulation_limit].empty?

      job_counter = params[:job_counter].to_i
      # getting time limit in minutes but script accept seconds
      time_limit = params[:time_limit].to_i * 60
      simulation_limit = params[:simulation_limit]
      credentials = session[:grid_credentials]

      upload_simulation_manager(credentials)
      run_grid_jobs(credentials, job_counter, time_limit, simulation_limit)

    else
      flash[:error] = "Provide all jobs parameters. You must first configure access to PL-Grid resources."
    end

    redirect_to :action => :index
  end

  def run_amazon_instances
    vm_counter = params[:vm_counter].to_i
    #ec2_region = @ec2.regions[params[:region]]
    begin
      ec2_region = @ec2.regions["us-east-1"]
      @new_instances = ec2_region.instances.create(:image_id => "ami-e93b8d80",
                                             :count => vm_counter,
                                             :instance_type => params[:vm_type],
                                             :security_groups => ["quicklaunch-1"])

      if @new_instances.class.name == "AWS::EC2::Instance"
        @new_instances = [@new_instances]
      end

    rescue Exception => e
      error_msg = "Error occured during updating EC2 instances - #{e.message}"
      logger.error(error_msg)
      flash[:error] = error_msg
    end

    redirect_to :action => :index
  end

  def monitor_amazon_new_instance(vm_instance)
    last_status = vm_instance.status

    while last_status != :terminated
      sleep 15
      if vm_instance.status != last_status
        last_status = vm_instance.status
        vm_row = escape_javascript(render_to_string(:partial => "amazon_vm", :locals => {:vm_instance_id => vm_instance.id, :vm_status => last_status.to_s}))
        # Socky.send("$('#amazon_vm_#{vm_instance.id}').replaceWith('#{vm_row}')", :channels => "infrastructure")
      end
    end

    vm_row = escape_javascript(render_to_string(:partial => "amazon_vm", :locals => {:vm_instance_id => vm_instance.id, :vm_status => last_status.to_s}))
    # Socky.send("$('#amazon_vm_#{vm_instance.id}').replaceWith('#{vm_row}')", :channels => "infrastructure")
  end

  def prepare_amazon_new_instance(vm_instance)
    sleep 2 while vm_instance.status == :pending
    return if vm_instance.status != :running

    execute_commands_on_instance_with_counter(commands_to_prepare_amazon_vm, vm_instance, 10)
  end
  
  def infrastructure_info
    collect_infrastructure_info

    render json: @infrastructure_info
  end

  # ============================ PRIVATE METHODS ============================
  private

  def run_vms_with_reqs(number, cpus, memory, start=false)
    pms_capacity = {}
    PhysicalMachine.all.each do |pm|
      cpu_capacity, mem_capacity = pm.cpus, pm.memory
      pm.virtual_machines.each { |vm| cpu_capacity -= vm.cpus; mem_capacity -= vm.memory }
      pms_capacity[pm.ip] = [cpu_capacity, mem_capacity]
    end

    counter = 0
    while counter < number do
      used_resources = {}
      pms_capacity.each do |ip, capacity|
        if capacity[0] >= cpus and capacity[1] >= memory then
          pm = PhysicalMachine.find_by_ip(ip)
          name = find_name_for_vm(pm)

          conn = pm.get_libvirt_connection
          vm = run_vm(name, cpus, memory, conn)
          pm.virtual_machines << vm
          pm.save

          if start then
            Net::SSH.start(vm.physical_machine.ip, vm.physical_machine.username) do |ssh|
              ssh.exec!("virsh start #{vm.name}")
            end
            vm.state = 'running'
            logger.debug("Starting #{vm.name}")
          else
            vm.state = 'shutdown'
          end

          vm.save

          vm_json = "{ 'id': 'pm-#{pm.id}',
                               'children': [ { 'id' : 'vm-#{vm.id}',
                                               'name' : '#{escape_javascript(render_to_string :partial => "vm_node", :locals => {:vm => vm})}' } ]}"

          # Socky.send("infrastructure_tree.addSubtree(#{vm_json}, 'replot', { });", :channels => "infrastructure")

          used_resources[ip] = [capacity[0] - cpus, capacity[1] - memory]
          counter += 1

          break if counter == number
        end
      end

      if used_resources.empty? then
        return number - counter + 1
      else
        used_resources.each { |ip, new_capacity| pms_capacity[ip] = new_capacity }
      end
    end

    return 0
  end

  def run_vm(name, cpus, memory, conn)
    result = %x[cp #{@@tamplate_dir}#{@@tamplate_name} #{@@tamplate_dir}#{name}.img]

    new_dom_xml = "<domain type='kvm'>
        <name>#{name}</name>
        <uuid></uuid>
        <memory>#{(memory * 1024).to_i}</memory>
        <currentMemory>#{(memory * 1024).to_i}</currentMemory>
        <vcpu>#{cpus}</vcpu>
        <os>
          <type arch='i686' machine='pc-0.12'>hvm</type>
          <boot dev='hd'/>
        </os>
        <features>
          <acpi/>
          <apic/>
          <pae/>
        </features>
        <clock offset='utc'/>
        <on_poweroff>destroy</on_poweroff>
        <on_reboot>restart</on_reboot>
        <on_crash>restart</on_crash>
        <devices>
          <emulator>/usr/bin/kvm</emulator>
          <disk type='file' device='disk'>
            <driver name='qemu' type='raw'/>
            <source file='#{@@tamplate_dir}#{name}.img'/>
            <target dev='hda' bus='ide'/>
          </disk>
          <disk type='block' device='cdrom'>
            <driver name='qemu' type='raw'/>
            <target dev='hdc' bus='ide'/>
            <readonly/>
          </disk>
          <interface type='network'>
            <source network='default'/>
            <target dev='vnet0'/>
          </interface>
          <console type='pty'>
            <target port='0'/>
          </console>
          <console type='pty'>
            <target port='0'/>
          </console>
          <input type='mouse' bus='ps2'/>
          <graphics type='vnc' port='-1' autoport='yes' keymap='en-us'/>
          <video>
            <model type='cirrus' vram='9216' heads='1'/>
          </video>
        </devices>
      </domain>"
#    logger.info(new_dom_xml)

    domain = conn.define_domain_xml(new_dom_xml)
    VirtualMachine.new(:name => domain.name,
                       :state => VirtualMachine.state_string(domain.info.state),
                       :cpus => cpus,
                       :memory => memory)
  end

  def find_name_for_vm(pm)
    i = 1
    candidate = "pm_#{pm.id}_vm_"

    existing_names = pm.virtual_machines.map { |vm| vm.name }
    while existing_names.include?(candidate + i.to_s) do
      i += 1
    end

    candidate + i.to_s
  end

  #  registering aws-related-elements
  def register_to_amazon
    if params[:aws_access_key]
      session[:aws_access_key] = params[:aws_access_key]
      session[:aws_secret] = params[:aws_secret]
    end

    if params[:grouping_factor]
      session[:grouping_factor] = params[:grouping_factor]
    end

    if session[:aws_access_key]
      begin
        @ec2 = AWS::EC2.new(:access_key_id => session[:aws_access_key],
                            :secret_access_key => session[:aws_secret])
        @ec2_running_instances = {}
        @ec2_running_instances = @ec2.instances.inject({}) { |m, i| m[i.id] = i.status.to_s; m }.select { |i, s| s != "terminated" }

        activate_amazon_monitoring_thread
      rescue Exception => e
        session[:aws_access_key] = nil
        session[:aws_secret] = nil
        session[:grouping_factor] = nil
        flash[:error] = "AWS credentials are not correct - #{e.message}"
      end
    else
      @ec2_running_instances = mock_ec2_instances
    end
  end

  def execute_commands_on_instance_with_counter(commands, instance, counter)
    i = 0
    private_key_path = File.join(Rails.root, "tmp", session[:aws_private_key])

    while i < counter
      i += 1
      begin
        # TODO repair
        Net::SSH.start(instance.ip_address, "", :password => "") do |ssh|
          logger.debug("Access to EC2 instance")
          ssh.exec!(commands.join(";"))
        end

        return # if commands executed
      rescue Exception => e
        logger.error("Accessing EC2 instance failure: #{e.message}")
        sleep 5
      end
    end

  end

  def commands_to_prepare_amazon_vm
    [
        "if ! [ -d ~/jre1.7.0 ]; then wget http://fivo.cyf-kr.edu.pl/eusas/downloads/jre-7-linux-x86.gz; tar xzvf jre-7-linux-x86.gz; fi",
        "export PATH=~/jre1.7.0/bin:$PATH",
        "if ! [ -d ~/eusas-abs-bin ]; then wget http://fivo.cyf-kr.edu.pl/eusas/downloads/eusas-abs-bin-20120402.zip; unzip eusas-abs-bin-20120402.zip; fi",
        "cd eusas-abs-bin",
        "if ! [ -f ./eusas_run.sh ]; then wget http://fivo.cyf-kr.edu.pl/eusas/downloads/eusas_run.sh; fi",
        "sh eusas_run.sh &"
    ]
  end

  def activate_amazon_monitoring_thread
    logger.debug("AMAZON_MONITORING_THREAD_ACTIVATED is #{Rails.configuration.amazon_monitoring_thread_activated}")
    if not Rails.configuration.amazon_monitoring_thread_activated
      logger.debug("Activating Amazon monitoring thread")
      Rails.configuration.amazon_monitoring_thread_activated = true
      spawn(:method => :thread, :argv => "AMAZON_MONITORING_THREAD") do
        amazon_monitoring_function
        Rails.configuration.amazon_monitoring_thread_activated = false
        logger.debug("AMAZON_MONITORING_THREAD_ACTIVATED is #{Rails.configuration.amazon_monitoring_thread_activated}")
      end
    else
      logger.debug("Amazon monitoring thread is running")
    end
  end
  
  def activate_plgrid_monitoring_thread
    # user_id = session[:user]
    #logger.debug("PLGRID_MONITORING_THREAD_ACTIVATED is #{Rails.configuration.plgrid_monitoring_thread_activated}")
    #if not Rails.configuration.plgrid_monitoring_thread_activated
    #  logger.debug("Activating PL-Grid monitoring thread")
    #  Rails.configuration.plgrid_monitoring_thread_activated = true
    #  spawn(:method => :thread, :argv => "PLGRID_MONITORING_THREAD") do
    #    GridJob.plgrid_monitoring_function
    #    Rails.configuration.plgrid_monitoring_thread_activated = false
    #    logger.debug("PLGRID_MONITORING_THREAD_ACTIVATED is #{Rails.configuration.plgrid_monitoring_thread_activated}")
    #  end
    #else
    #  logger.debug("Amazon monitoring thread is running")
    #end
  end 

  def amazon_monitoring_function
    old_state = {}
    while session[:aws_access_key]
      instances_to_update = {}

      begin
        current_state = @ec2.instances.inject({}) { |m, i| m[i.id] = i.status.to_s; m }.select { |i, s| s != "terminated" }

        current_state.each do |instance_id, status|
          if not (old_state.include?(instance_id) and (old_state[instance_id] == status))
            cloud_machine = CloudMachine.find_by_amazon_id(instance_id)
            if cloud_machine.nil?
              cloud_machine = CloudMachine.new(:user_id => session[:user], :amazon_id => instance_id)
            end
            cloud_machine.amazon_status = status
            cloud_machine.save
            
            instances_to_update[instance_id] = status
          end
        end
        
        CloudMachine.where(:user_id => session[:user]).each do |vm|
          if not current_state.include?(vm.amazon_id)
            vm.destroy
          end
        end

        old_state.each do |instance_id, status|
          if not current_state.include?(instance_id)
            cloud_machine = CloudMachine.find_by_amazon_id(instance_id)
            if not cloud_machine.nil?
              cloud_machine.destroy
            end
            
            
            instances_to_update[instance_id] = "terminated"
          end
        end

        # Socky.send(amazon_instances_batch_update(instances_to_update), :channels => "infrastructure")
        break if current_state.empty? and (not old_state.empty?)

        old_state = current_state

      rescue Exception => e
        error_msg = "Error occured during updating EC2 instances - #{e.message}"
        logger.error(error_msg)
        # Socky.send("show_flash_error('#{error_msg}')", :channels => "infrastructure")
      end

      sleep(15)
    end
  end

  def amazon_instances_batch_update(instances_to_update)
    batch_update = ""

    instances_to_update.each do |instance_id, status|
      new_node_html = render_to_string(:partial => "amazon_vm_node",
                                       :locals => {:vm_instance_id => instance_id, :vm_status => status})
      batch_update += "$('#amazon-vm-#{instance_id}').html(\"#{escape_javascript new_node_html}\");"
    end

    batch_update
  end

  def upload_simulation_manager(credentials)
    latest_version, simulation_manager_path = latest_simulation_manager_version
    # check if latest version is on the server, if not then upload and unzip
    Net::SSH.start(credentials.host, credentials.login, :password => credentials.password) do |ssh|
      directory_exists = ssh.exec!("ls -l eusas-abs-bin/eusas-abs-#{latest_version}.jar")
      logger.info(directory_exists)
      if directory_exists.include?("No such file or directory")
        logger.info("Uploading latest version of simulation manager to #{credentials.host}")
        ssh.exec!("rm -rf eusas-abs-bin")
        Net::SCP.start(credentials.host, credentials.login, :password => credentials.password) do |scp|
          scp.upload! simulation_manager_path, "."
        end

        ssh.exec!("unzip #{File.basename(simulation_manager_path)}; rm #{File.basename(simulation_manager_path)}")
      end
    end

  end

# TODO FIXME - eusas_repo_path is deprecated
  def latest_simulation_manager_version
    distribution_path = File.join(Rails.configuration.eusas_repo_path, "..", "dist")

    version = Dir.entries(distribution_path).select { |entry| entry.ends_with?(".zip") }.
        map { |entry| entry[entry.rindex("-")+1..-5].to_i }.max

    return version, File.join(distribution_path, "eusas-abs-bin-#{version}.zip")
  end

  def run_grid_jobs(credentials, job_counter, time_limit, simulation_limit)
    spawn do
      simulation_manager_params = "-t #{time_limit} -c #{simulation_limit} -p #{credentials.password}"
      commands = ["cd eusas-abs-bin",
                  "java -cp eusas-abs*.jar eusas.schedulers.GridSender -v #{simulation_manager_params}"]
      # submitted_jobs_ids = []
      Net::SSH.start(credentials.host, credentials.login, :password => credentials.password) do |ssh|
        1.upto(job_counter) do

          grid_job_id = submit_job(ssh, commands)

          if grid_job_id.nil?
            logger.error("Could not submit grid job")
          else
            gj = GridJob.new(:time_limit => time_limit, :simulation_limit => simulation_limit,
                             :user_id => session[:user], :grid_id => grid_job_id)
            gj.save
            # submitted_jobs_ids << grid_job_id
          end
        end
      end

      # start_grid_monitoring_thread(submitted_jobs_ids, time_limit, credentials)
      # Socky.send("window.location.reload()", :channels => "infrastructure") if not submitted_jobs_ids.blank?
    end
  end

  def remove_plgrid_job_node_command(grid_job_id)
    command =  " var vm_node = $jit.Graph.Util.getNode(infrastructure_tree.graph, 'plgrid-job-#{grid_job_id}');"
    command += " var parentChildrenCount = 0;"
    command += " var parentNode = $jit.Graph.Util.getParents(vm_node)[0];"
    command += " infrastructure_tree.removeSubtree('plgrid-job-#{grid_job_id}', true, 'replot', { } );"
    command += " parentNode.eachSubnode(function(subnode) { parentChildrenCount += 1; });"
    command += " if(parentChildrenCount == 0) { alert(parentNode.id); infrastructure_tree.removeSubtree(parentNode.id, true, 'replot', { } ); infrastructure_tree.select('1'); }"

    command
  end

  def mock_ec2_instances
    {
        "i-8c898af1" => "stopped",
        "i-8c898af2" => "running",
        "i-8c898af3" => "stopped",
        "i-8c898af4" => "running",
        "i-8c898af5" => "stopped",
        "i-8c898af6" => "running",
        "i-8c898a11" => "stopped",
        "i-8c898a12" => "running",
        "i-8c898a13" => "stopped",
        "i-8c898a14" => "running",
        "i-8c898a15" => "stopped",
        "i-8c898a16" => "running",
        "i-8c898a21" => "stopped",
        "i-8c898a22" => "running",
        "i-8c898a23" => "stopped",
        "i-8c898a24" => "running",
        "i-8c898a25" => "stopped",
        "i-8c898a26" => "running",
        "i-8c898a31" => "stopped",
        "i-8c898a32" => "running",
        "i-8c898a33" => "stopped",
        "i-8c898a34" => "running",
        "i-8c898a35" => "stopped",
        "i-8c898a36" => "running"
    }
  end

  def submit_job(ssh, commands)
    submit_job_output = ssh.exec!(commands.join(";"))
    logger.debug("Output lines: #{submit_job_output}")

    if submit_job_output != nil
      output_lines = submit_job_output.split("\n")

      output_lines.each_with_index do |line, index|
        if line.include?("Your job identifier is:")

          return output_lines[index + 1] if output_lines[index + 1].start_with?("http")
          return output_lines[index + 2] if output_lines[index + 2].start_with?("http")

        end
      end
    end

    nil
  end

  def start_grid_monitoring_thread(submitted_jobs_ids, time_limit, credentials)
    spawn do
      while not submitted_jobs_ids.blank? do
        sleep(time_limit/3)

        Net::SSH.start(credentials.host, credentials.login, :password => credentials.password) do |ssh|
          submitted_jobs_ids.each do |grid_job_id|
            job_status = ssh.exec!("glite-wms-job-status #{grid_job_id}")
            if not job_status.include?("Current Status:     Running")
              gj = GridJob.find_by_grid_id(grid_job_id)

              # Socky.send(remove_plgrid_job_node_command(gj.id), :channels => "infrastructure")
              logger.info("Grid job with id: #{gj.id} --- #{gj.grid_id} has been deleted")
              GridJob.delete(gj.id)

              submitted_jobs_ids.delete(grid_job_id)
            end
          end
        end
      end
    end
  end
  
  def collect_infrastructure_info
    @infrastructure_info = {}
    private_all_machines = SimulationManagerHost.all.count
    private_idle_machines = SimulationManagerHost.select{|x| x.state == "not_running"}.count
    
    @infrastructure_info[:private] = "Currently #{private_idle_machines}/#{private_all_machines} machines are idle."
    
    user_id = session[:user]
    return if user_id.nil?
    
    plgrid_jobs = GridJob.where(:user_id => user_id).count
    @infrastructure_info[:plgrid] = "Currently #{plgrid_jobs} jobs are running."
    # amazon_instances = (defined? @ec2_running_instances) ? @ec2_running_instances.size : 0
    amazon_instances = CloudMachine.where(:user_id => user_id).count
    
    @infrastructure_info[:amazon] = "Currently #{amazon_instances} Virtual Machines are running."
  end

end

