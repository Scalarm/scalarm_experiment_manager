require "aws-sdk"

module InfrastructureHelper

  def vm_manage_button(icon, operation, id)
   url_arg_hash = { :action => :manage_vm, :vm_id => id }
   link_to image_tag(icon, :alt => "private_#{operation}"),
           url_for(url_arg_hash.merge(:operation => operation)), :remote => true, :onClick => "$('#vm-busy-#{id}').show()"
  end

  def ec2_vm_manage_button(icon, operation, id)
    url_arg_hash = { :action => :manage_ec2_vm, :vm_id => id }
    link_to image_tag(icon, :alt => "amazon_#{operation}"),
            url_for(url_arg_hash.merge(:operation => operation)), :remote => true, :onClick => "$('#vm-busy-#{id}').show()"
  end

  def amazon_regions
    if @ec2.nil?
      []
    else
      options_for_select(@ec2.regions.map{|region| [region.name, region.name]})
    end
  end

  def infrastructure_graph_data
    infrastructure_json = "var infrastructure_json = { "
    # center node start
    infrastructure_json += "'id' : '1',"
    infrastructure_json += "'name' : 'Data Farming Infrastructure',"
    infrastructure_json += "'children' : [ "

    # private infrastructure
    infrastructure_json += "{ 'id' : '1_1',"
    infrastructure_json += "'name' : new window.PrivateInfrastructureFacet().label().html(),"
    infrastructure_json += "'children' : [ "

    infrastructure_json += SimulationManagerHost.all.map{|sm|
      "window.SimulationManagerFacet.create_json_obj('#{sm.id}', '#{sm.state_in_json}')"}.join(",")

    infrastructure_json += " ],"
    infrastructure_json += "'data' : { } }"

    # amazon ec2 infrastructure
    infrastructure_json += ", { 'id' : '1_2',"
    infrastructure_json += "'name' : '#{amazon_cloud_label}',"
    infrastructure_json += "'children' : [ "
    infrastructure_json += amazon_instances_description
    infrastructure_json += " ],"
    infrastructure_json += "'data' : { } }"

    # plgrid infrastructure
    infrastructure_json += ", { 'id' : '1_3',"
    infrastructure_json += "'name' : '#{escape_javascript plgrid_infrastructure_label}',"
    infrastructure_json += "'children' : [ "
    infrastructure_json += plgrid_job_groups_description
    infrastructure_json += " ],"
    infrastructure_json += "'data' : { } }"

    # Rails.logger.debug("PLGRID: #{plgrid_job_groups_description}")

    infrastructure_json += " ],"
    infrastructure_json += "'data' : { }"

    infrastructure_json += " };"

    infrastructure_json
  end

  def amazon_cloud_label
    label = "<div>Amazon Elastic Compute Cloud<br/>"
    label += image_tag("run.png", :onclick => "$('[alt=\"amazon_run\"]').each(function(i, element) { $(element).parent().click() })") + " "
    label += image_tag("stop.png", :onclick => "$('[alt=\"amazon_stop\"]').each(function(i, element) { $(element).parent().click() })") + " "
    label += image_tag("unregister.png", :onclick => "$('[alt=\"amazon_destroy\"]').each(function(i, element) { $(element).parent().click() })") + " "
    label += link_to_function(image_tag("configure.png", :size => "16x16"), "$('#amazon_configure').dialog('open')") + " "
    label += link_to_function(image_tag("add-icon.png", :size => "16x16"), "$('#amazon_add_instance').dialog('open')")

    escape_javascript(label + "</div>")
  end

  def amazon_instances_description
    #return "" if not session["aws_access_key"]


    group_size = if session["grouping_factor"] then
                   session["grouping_factor"].to_i
                 else
                   5 # DEFAULT VM GROUP SIZE
                 end
    group_count = if @ec2_running_instances.size == 0 then
                    0
                  else
                    ((@ec2_running_instances.size-1) / group_size) + 1
                  end

    vms_json = @ec2_running_instances.each.map { |instance_id, status| amazon_instance_to_json(instance_id, status) }

    amazon_vms_json = []
    1.upto(group_count) do |group_index|
      amazon_vms_json << "{ 'id' : 'vms_group_#{group_index}',
          'name' : '#{amazon_vms_group_label(group_index, group_size, vms_json.size)}',
          'children' : [ #{vms_json[group_size*(group_index - 1), group_size].join(",")} ] }"
    end

    amazon_vms_json.join(",")
  end

  def amazon_vms_group_label(group_index, group_size, max_size)
    amazon_group_id = "vms_group_#{group_index}"
    label = "<div>" + image_tag("amazon_vms_group.png", :size => "16x16")
    label += " VMs #{group_size*(group_index - 1) + 1} - #{[group_size*group_index, max_size].min}<br/>"
    label += image_tag("run.png", :onclick => escape_javascript("run_on_vms_from_group('#{amazon_group_id}', 'run')")) + " "
    label += image_tag("stop.png", :onclick => escape_javascript("run_on_vms_from_group('#{amazon_group_id}', 'stop')")) + " "
    label += image_tag("unregister.png", :onclick => escape_javascript("run_on_vms_from_group('#{amazon_group_id}', 'destroy')")) + " "

    label + "</div>"
  end

  def physical_machine_to_json(pm)
    "{ 'id' : 'pm-#{pm.id}',
       'name' : '#{escape_javascript(physical_machine_label(pm))}',
       'children' : [ #{pm.virtual_machines.map{|vm| virtual_machine_to_json(vm) }.join(",")} ],
       'data' : {}
    }"
  end

  def physical_machine_label(pm)
    label  = image_tag "server-icon.png"
    label += " #{pm.ip} "

    label += image_tag("run.png", :onclick => "run_on_vms_from_pm('pm-#{pm.id}', ['create','resume'])") + " "
    label += image_tag("pause.png", :onclick => "run_on_vms_from_pm('pm-#{pm.id}', ['suspend'])") + " "
    label += image_tag("stop.png", :onclick => "run_on_vms_from_pm('pm-#{pm.id}', ['destroy'])") + " "

    label += image_tag("vm.png", :onclick => "$('#machine_id').val(#{pm.id}); $('#dialog-form').dialog('open');") + " "
    label += link_to(image_tag("unregister.png"), url_for({:action => :manage_pm, :pm_id => pm.id }),
                    :method => :delete, :remote => true) + " "
    pm_info_dialog_args = [ pm.ip, pm.username, pm.cpus, pm.cpu_model, pm.cpu_freq, pm.memory ].join("','")
    label += image_tag("info.gif", :onclick => "open_pm_info_dialog('#{pm_info_dialog_args}')")


    label
  end

  def virtual_machine_to_json(vm)
    "{ 'id' : 'vm-#{vm.id}',
       'name' : '#{escape_javascript(virtual_machine_label(vm))}',
       'children' : [],
       'data' : {}
    }"
  end

  def virtual_machine_label(vm)
    label = "<div>"
    label += image_tag "loading.gif", :id => "vm-busy-#{vm.id}", :size => "16x16", :style => "display: none;"
    label += "#{image_tag "icon_linux_smaller.png"} #{vm.name} <br/> State: #{vm.state} <br/> <div>"

    label += if vm.state != 'running'
      if vm.state != 'paused'
        vm_manage_button("run.png", "create", vm.id)
      else
        vm_manage_button("run.png", "resume", vm.id)
      end
    else
      image_tag("run_gray.png")
    end

    label += " "
    label += if vm.state == 'running'
      vm_manage_button "pause.png", "suspend", vm.id
    else
      image_tag("pause_gray.png")
    end

    label += " "
    label += if vm.state != 'shutdown'
      vm_manage_button "stop.png", "destroy", vm.id
    else
      image_tag("stop_gray.png")
    end

    label += " "
    label += link_to image_tag("unregister.png"), url_for(:action => :destroy_vm, :vm_id => vm.id), :remote => true, :onClick => "$('#vm-busy-#{vm.id}').show()"
    label += " "

    vm_info_dialog_args = [ vm.name, vm.cpus, vm.memory ].join("','")
    label += image_tag("info.gif", :onclick => "open_vm_info_dialog('#{vm_info_dialog_args}')")
    label += " "

    label += "</div></div>"

    label
  end

  def amazon_instance_to_json(instance_id, status)
    "{ 'id' : 'amazon-vm-#{instance_id}',
       'name' : '#{escape_javascript(amazon_instance_label(instance_id, status))}',
       'children' : [],
       'data' : {}
    }"
  end

  def amazon_instance_label(vm_instance_id, vm_status)
    label = "<div>"
    label += image_tag "amazon_icon.jpg", :size => "16x16"
    label += " ID: #{vm_instance_id}<br/>State: #{vm_status}<br/>"

    label += if ["stopped"].include?(vm_status)
               ec2_vm_manage_button "run.png", "run", vm_instance_id
             else
               image_tag("run_gray.png")
             end

    label += " "
    label += if ["running"].include?(vm_status)
              ec2_vm_manage_button "stop.png", "stop", vm_instance_id
             else
              image_tag("stop_gray.png")
             end

    label += " "
    label += if ["running", "stopped"].include?(vm_status)
              ec2_vm_manage_button "unregister.png", "destroy", vm_instance_id
             else
              image_tag("unregister_gray.png")
             end

    label += " "
    label += image_tag "loading.gif", :id => "vm-busy-#{vm_instance_id}", :size => "16x16", :style => "display: none;"

    label + "</div>"
  end

  def plgrid_infrastructure_label
    label = "<div>"
    label += image_tag "plgrid_icon.png", :size => "16x16"
    label += " PL-Grid infrastructure<br/>"
    label += link_to_function(image_tag("run.png", :size => "16x16"), "$('#plgrid_run_jobs').dialog('open')")
    label += link_to_function(image_tag("configure.png", :size => "16x16"), "$('#plgrid_configure').dialog('open')") + " "
    label + "</div>"
  end

  def plgrid_job_groups_description
    @user_grid_jobs = GridJob.where(:user_id => session[:user].to_i)

    grouping_factor = session[:plgrid_grouping_factor].to_i
    grouping_factor = 20 if grouping_factor == 0

    group_count = @user_grid_jobs.empty? ? 0 : ((@user_grid_jobs.size-1) / grouping_factor) + 1

    plgrid_jobs_json = @user_grid_jobs.map{ |grid_job| plgrid_grid_job_to_json(grid_job) }

    plgrid_job_groups_json = []
    1.upto(group_count) do |group_index|
      plgrid_job_groups_json << "{ 'id' : 'plgrid_job_group_#{group_index}',
            'name' : '#{plgrid_job_group_label(group_index, grouping_factor, @user_grid_jobs.size)}',
            'children' : [ #{plgrid_jobs_json[grouping_factor*(group_index - 1), grouping_factor].join(",")} ] }"
    end

    plgrid_job_groups_json.join(",")
  end

  def plgrid_grid_job_to_json(grid_job)
    "{ 'id' : 'plgrid-job-#{grid_job.id}',
       'name' : '#{escape_javascript(plgrid_job_label(grid_job))}',
       'children' : [],
       'data' : {}
    }"
  end

  def plgrid_job_group_label(group_index, group_size, max_size)
    label = "<div>" + image_tag("plgrid_icon.png", :size => "16x16")
    label += " Grid Jobs #{group_size*(group_index - 1) + 1} - #{[group_size*group_index, max_size].min}"
    label + "</div>"
  end

  def plgrid_job_label(grid_job)
     label = "<div>"
     #label += image_tag "plgrid_icon.png", :size => "16x16"
     label += " ID: #{grid_job.id}, Created at:<br/>"
     label += "#{grid_job.created_at.to_s[0..-5]}<br/>"
     label += "Time limit: #{(grid_job.time_limit.to_i/60)} [min]"
     #label += "Simulation limit: #{grid_job.simulation_limit}<br/>"
     label + "</div>"
  end

end
