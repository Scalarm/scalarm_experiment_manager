function simulation_manager_host_remote_call(sm_id, action_name) {
    var sm_facet = new window.SimulationManagerFacet(sm_id, null);
    sm_facet.manage_remote_object(action_name);
}

function prepare_dialog(id) {
    $('#'+id).dialog({
        autoOpen: false,
        width: 450,
        modal: true,
        buttons: { },
        close: function() { }
    });
}

function infrastructure_init() {
    $("#infrastructure_tree").jstree({
        "themes":{ "icons":false, "dots":false },
        "plugins":[ "themes", "html_data", "crrm" ]
    });

    $("#site_title").html("Infrastructure manager");
}

var infrastructure_tree;
function infrastructure_graph_spacetree() {
    //Create a new ST instance
    infrastructure_tree = new $jit.ST({
        //id of viz container element
        injectInto: 'infrastructure_graph',
        //set duration for the animation
        duration: 600,
        //set animation transition type
        transition: $jit.Trans.Quart.easeInOut,
        //set distance between node and its children
        levelDistance: 50,
        levelsToShow: 4,
        //enable panning
        Navigation: {
          enable:true,
          panning:true
        },
        //set node and edge styles
        //set overridable=true for styling individual
        //nodes or edges
        Node: {
            height: 65,
            width: 130,
            type: 'rectangle',
//            color: '#81BEF7',
            overridable: true
        },

        Edge: {
            type: 'bezier',
            overridable: true
        },

        onBeforeCompute: function(node){
//            Log.write("loading " + node.name);
        },

        onAfterCompute: function(){
//            Log.write("done");
        },

        //This method is called on DOM label creation.
        //Use this method to add event handlers and styles to
        //your node.
        onCreateLabel: function(label, node) {
            label.id = node.id;
            label.innerHTML = node.name;
            label.onclick = function() {
                if(node.getSubnodes().length > 1) {
//                if(normal.checked) {
                    infrastructure_tree.onClick(node.id);
//                } else {
//                infrastructure_tree.setRoot(node.id, 'animate');
//                }
                }
            };

//            var parents = node.getParents()
//            if(parents.length > 0) {
//                var parent = parents[0];
////                alert("Parent name is " + parent.name);
//                if(parent.name == "Private Infrastructure") {
//                    width = 110;
//                }
//
//            }

            //set label styles
            var style = label.style;
            style.width = '117px';
            style.height = 40 + 'px';
            style.cursor = 'pointer';
            style.color = '#333';
            style.fontSize = '0.9em';
            style.textAlign= 'center';
            style.paddingTop = '5px';
            style.paddingLeft = '5px';
        },

        //This method is called right before plotting
        //a node. It's useful for changing an individual node
        //style properties before plotting it.
        //The data properties prefixed with a dollar
        //sign will override the global node style properties.
        onBeforePlotNode: function(node) {
            var parents = node.getParents();

            if (parents.length == 0) {
                node.data.$color = "#DF7401";
//              Infrastructure level
                node.eachSubnode(function(infrastructure_node) {
                    infrastructure_node.data.$color = "#F7BE81";
                    infrastructure_node.eachSubnode(function(grouping_node) {
                        grouping_node.data.$color = "#F5DA81";
                        grouping_node.eachSubnode(function(leaf_node) {
                            leaf_node.data.$color = "#D0F5A9";
                        });
                    });
                });
            }
        },

        //This method is called right before plotting
        //an edge. It's useful for changing an individual edge
        //style properties before plotting it.
        //Edge data proprties prefixed with a dollar sign will
        //override the Edge global style properties.
        onBeforePlotLine: function(adj){
            if (adj.nodeFrom.selected && adj.nodeTo.selected) {
                adj.data.$color = "#555";
                adj.data.$lineWidth = 3;
            }
            else {
                adj.data.$color = "#555";
                delete adj.data.$lineWidth;
            }
        }
    });

    //load json data
    infrastructure_tree.loadJSON(infrastructure_json);
    //compute node positions and layout
    infrastructure_tree.compute();
    //optional: make a translation of the tree
    infrastructure_tree.geom.translate(new $jit.Complex(-200, 0), "current");
    //emulate a click on the root node.
    infrastructure_tree.onClick(infrastructure_tree.root);
}

function open_vm_info_dialog(vm_name, vm_cpus, vm_memory) {
  $("#vm_info_name").html(vm_name);
  $("#vm_info_cpus").html(vm_cpus);
  $("#vm_info_memory").html(vm_memory);
  
  $("#vm_info_dialog").dialog("open");
}

function open_pm_info_dialog(pm_ip, pm_username, pm_cpus, pm_cpu_model, pm_cpu_freq, pm_memory) {
  $("#pm_info_ip").html(pm_ip);
  $("#pm_info_username").html(pm_username);  
  $("#pm_info_cpus").html(pm_cpus);
  $("#pm_info_cpu_model").html(pm_cpu_model);
  $("#pm_info_cpu_freq").html(pm_cpu_freq);
  $("#pm_info_memory").html(pm_memory);
  
  $("#pm_info_dialog").dialog("open");
}

function clear_register_dialog() {
  $("#register-busy").hide();
  $("#physical_machine_ip").val("");
  $("#physical_machine_username").val("");
}

function run_on_vms_from_pm(pm_node_id, operation_list) {
    var pm_node = infrastructure_tree.graph.getNode(pm_node_id);
    pm_node.eachSubnode(function(child_node) {
        var child_node_id = child_node.id;
        $.each(operation_list, function(index, operation_name) {
            var vm_node_query = "#" + child_node_id + ' [alt=\"private_' + operation_name + '\"]';
            $(vm_node_query).each(function(i, element) { $(element).parent().click() });
        });
    });
}

function run_on_vms_from_group(amazon_group_id, operation_name) {
    var group_node = infrastructure_tree.graph.getNode(amazon_group_id);
    group_node.eachSubnode(function (child_node) {
        var child_node_id = child_node.id;
        var vm_node_query = "#" + child_node_id + ' [alt=\"amazon_' + operation_name + '\"]';
        $(vm_node_query).each(function (i, element) { $(element).parent().click() });
    });
}