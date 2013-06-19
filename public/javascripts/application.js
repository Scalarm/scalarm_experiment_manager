// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function string_with_delimeters() {
    var string_copy = this.split("").reverse().join("");
    var len = 3; var num_of_comas = 0;

    while((len + num_of_comas <= string_copy.length) && string_copy.length > 3) {
        string_copy = string_copy.substr(0,len) + "," + string_copy.substr(len);
        num_of_comas = 1; len += 4;
    }

    return string_copy.split("").reverse().join("");
}

String.prototype.with_delimeters = string_with_delimeters;

function change_param_select(obj) {
  $(obj).parent().parent().find("p select").each(function(index, elem) {
    elem.selectedIndex = obj.selectedIndex;
  });
}

function vm_busy_show(id) {
  $("#vm-busy-"+id).show();
}

function vm_busy_hide(id) {
  $("vm-busy-"+id).hide();
}

// NOT USED ANY MORE
//function update_monitoring_view(experiment_id) {
//  if($('#pb_busy:visible').length == 0 && ($('#experiment_id').attr('value') == experiment_id)) {
//    var page = $('#page_id').attr('value');
//    $.get('/experiments/update_state?experiment_id=' + experiment_id + '&page=' + page, function(data) { eval(data); });
//  }
//}

function check_experiment_size(experiment_id) {
  prepare_data_for_doe();
  data_txt = "experiment_id="+experiment_id;
  $("form input").each(function(index, element) {
    var el = $(element);
    data_txt += "&"+el.attr("name")+"="+el.attr("value");
  });

  $("#loading").show();
  $.post('check_experiment_size', data_txt,
    function(msg) { eval(msg); $("#loading").hide() }
  );
}


//  This function colors a single bar which has changed.
//  It also updates counters of experiment instances.
function update_progress_bar(bar_index, color, parts_size, statistics) {
  $("#exp_sent_counter").html(statistics[0].toString().with_delimeters());
  $("#exp_done_counter").html(statistics[1].toString().with_delimeters());
  $("#exp_done_percentage_counter").html(((statistics[1]/statistics[2])*100).toFixed(2));
  if(statistics.length > 3) {
    $("#ei_perform_time_avg").html(statistics[3]);
    $("#p_ei_perform_time_avg").show();
    $("#predicted_finish_time").html(statistics[4]);
    $("#p_predicted_finish_time").show();

    if(statistics[1]==statistics[2]) {
    	$("#p_predicted_finish_time").hide();
    }
  }

  if(statistics[1] == statistics[2]) {
    $("#get_results_button").show();
  }

  var canvas = document.getElementById("exp_progress_bar_2");
  var context = canvas.getContext("2d");
  var part_width = canvas.width / parts_size;

  context.fillStyle = "rgb(0, " + color + ", 0)";
  context.strokeStyle = "#rgb(200, 200, 200)";
  if(color > 250) {
    var width_fraction = 0.97;
  } else {
    var width_fraction = 0.95;
  }

  if(bar_index instanceof Array) {
  	left_index = bar_index[0]
    right_index = bar_index[1]

  	for (var i=left_index; i <= right_index; i++) {
		context.fillRect(part_width * i, 10, part_width * width_fraction, canvas.height - 10);
	};

  } else {
    context.fillRect(part_width * bar_index, 10, part_width*width_fraction, canvas.height - 10);
  }
}

function update_monitoring_section(bar_colors, statistics) {
//  update_monitoring_statistics(statistics);

  var canvas = document.getElementById("exp_progress_bar_2");
  var context = canvas.getContext("2d");
  var part_width = canvas.width / bar_colors.length;

  context.fillStyle = "rgb(255, 255, 255)";
  context.fillRect(0, 10, canvas.width, canvas.height - 10);

  for(var i = 0; i < bar_colors.length; i+=1) {
    var color = bar_colors[i];
    if(color == 0) {
      context.fillStyle = "#BDBDBD";
    } else {
      context.fillStyle = "rgb(0, " + color + ", 0)";
    }
    context.fillRect(part_width * i, 10, part_width*0.95, canvas.height - 10);
  }
}

function update_monitoring_statistics(statistics) {
//    alert("Update monitoring statistics");

    $("#exp_sent_counter").html(statistics[0].toString().with_delimeters());
    $("#exp_done_counter").html(statistics[1].toString().with_delimeters());
    $("#exp_done_percentage_counter").html(statistics[3]);

    if(statistics.length > 4) {
      $("#ei_perform_time_avg").html(statistics[4]);
      $("#p_ei_perform_time_avg").show();
      $("#predicted_finish_time").html(statistics[5]);
      $("#p_predicted_finish_time").show();
    }

    // if #instances_done == #experiment_size
    if(statistics[1] == statistics[3]) {
        $("#p_predicted_finish_time").hide();
        $("#get_results_button").show();
    }
}

/* Refreshes charts with MoE values */
function refresh_all_charts() {
  for(var i = 0; i < chart_tab.length; i += 1) {
    chart = chart_tab[i]; series = chart.series[0];
    $.ajax({
      url: '#{experiments_update_chart_data_path}',
      data: 'experiment_id=#{@experiment.id}&argument_name='+
            chart.xAxis_title+'&moe_name='+chart.yAxis_title+'&chart_id='+i,
      success: function(msg) { eval(msg); }
    });
  }
}

function add_doe_group_article(initial_dom_element) {
  $('#specification_article').after(initial_dom_element);
  last_index = doe_groups_last_index;

  $('#new_doe_group').attr("id", "doe_group_" + last_index);
  doe_type_label = $('#doe_type option:selected').text();
  doe_type_value = $('#doe_type option:selected').attr("value");
  $("#doe_group_" + last_index + " h3").html(doe_type_label + "-type group of parameters " + $("#doe_group_" + last_index + " h3").html());

  if(doe_groups_counter == 0) {
    for(var i = 0; i < params_for_doe.length; i += 1) {
      $("#doe_group_" + last_index + " select.arguments").append("<option value=\""+ params_for_doe[i] + "\">" + labels_for_doe[i] + "</option>");
    }
  } else {
    for(var i = 0; i < doe_groups_last_index; i += 1) {
      if($("#doe_group_" + i)) {
        $("#doe_group_" + last_index + " select.arguments").html($("#doe_group_" + i + " select.arguments").html());
      }
    }
  }

  $("#doe_group_" + last_index).append( $("<input/>").attr({id: "doe_group_"+last_index+"_type", value: doe_type_value, type: "hidden"}));
  $("#doe_group_" + last_index).fadeIn("slow");

  doe_groups_last_index += 1;
  doe_groups_counter += 1;

  hide_doe_inputs();
}

function add_doe_parameter(element) {
  parameter_to_add = $(element).siblings("select.arguments").children("option:selected");
  parameter_value = parameter_to_add.attr("value");
  parameter_label = parameter_to_add.text();

  doe_group_element = $(element).parent().parent();
  doe_group_element.find("ul.argument_list").append(
    $("<li/>").attr({param_name: parameter_value, param_label: parameter_label}).
      hide().append(parameter_label).append(
        $("<input/>").addClass("nice_button").attr(
          {
            onClick : "remove_doe_parameter(this)",
            value: "Remove",
            type: "button",
            style: "float: none;"}
        )
    )
  );

  doe_group_element.find("ul.argument_list li:hidden").fadeIn('slow');

  $("option[value*='" + parameter_value + "']").remove();

  hide_doe_inputs();
}

function add_all_doe_parameters(element) {
	add_parameter_button = $(element).siblings("input.nice_button")[0];
	while($(add_parameter_button).is(':visible')) {
		$(add_parameter_button).click();
	}
}

function remove_doe_parameter(element) {
  param_to_remove = $(element).parent();

  $("select.arguments").append("<option value=\""+ param_to_remove.attr("param_name") +
    "\">" + param_to_remove.attr("param_label") + "</option>");
  $(element).parent().fadeOut("slow", function() { $(this).remove() });

  show_doe_inputs();
}

function delete_doe_group(element) {
  doe_group_element = $(element).parent().parent();
  doe_group_element.find("ul.argument_list li").each(function() {
    remove_doe_parameter($(this).children("input.nice_button").first());
  });

  doe_group_element.fadeOut("slow", function() { $(this).remove() });
  doe_groups_counter -= 1;
}

function hide_doe_inputs() {
  if($("select.arguments").first().children("option").length == 0) {
    $("select.arguments").each(function() {
      $(this).siblings("input.nice_button").hide();
      $(this).hide();
    });
  }
}

function show_doe_inputs() {
  if($("select.arguments").first().children("option").length == 1) {
    $("select.arguments").each(function() {
      $(this).siblings("input.nice_button").show();
      $(this).show();
    });
  }
}

function prepare_data_for_doe() {
  $("input[name$='_params']").remove();
  doe_main_article = $("#specification_article");

  $("article[id^='doe_group']").each(function() {

    splitted_id = $(this).attr("id").split("_");
    index = splitted_id[splitted_id.length-1];

    doe_type = $("#doe_group_"+index+"_type").attr("value");
    doe_params = new Array();

    $(this).find("ul.argument_list li").each(function() {
      doe_params.push($(this).attr("param_name"));
    });

    if(doe_params.length > 0) {
      $(this).parent().append($("<input/>").attr({
        name: "doe_"+doe_type+"_"+index+"_params",
        type: "hidden",
        value: doe_params.join(",")})
      );

      // doe_settings = [];
      // doe_settings.push($(this).find("input[id='min']").attr("value"));
      // doe_settings.push($(this).find("input[id='max']").attr("value"));
      //
      // // alert(doe_settings.join(","));
      // $(this).parent().append($("<input/>").attr({
      //         name: "doe_"+doe_type+"_"+index+"_opts",
      //         type: "hidden", value: doe_settings.join(",")}));
    }
  });

  return false;
}

function show_waiting_div() {
  $('#waiting_div').show();
  $('html, body').animate({ scrollTop: $(document).height() }, 'slow');
}

function show_dialog_for_new_parameter_value(param_id, param_label, url, experiment_id) {
  $("#dialog").attr("title", "'"+param_label+"' parameter");
  $("#ui-dialog-title-dialog").html("'"+param_label+"' parameter");
  $("#dialog").dialog({'minWidth': 500, 'minHeight': 200});

  $.ajax({
    url: url,
    data: { 'param_name': param_id },
    success: function(msg) { $("#dialog").css("height", 250); $("#dialog").dialog({title: param_label})}
  });
}

function preparing_scenario() {
  if($('li.ui-selected').attr('file_name') == undefined) {
    alert('You must choose something!');
    return false;
  } else {
    $('#scenario_id').attr('value', $('li.ui-selected').attr('file_name'));
    var moas = new Array();
    $('#moa_list :checkbox').each(function(index, x) {
      if(x.checked) { moas.push(x.name); }
    });
    $('#moa_names').attr('value', moas.toString());
    return true;
  }
}

function prepare_accordion() {
  $('.accordion').accordion({ autoHeight: false, collapsible: true }).sortable({
    axis: 'y',
    handle: 'h3',
    stop: function() { stop = true; }
  });
}

function prepare_experiment_size_dialog() {
  $( '#experiment_size_dialog' ).dialog({
  	autoOpen: false,
  	height: 80,
  	width: 330,
  	modal: true,
  	buttons: { },
  	close: function() { }
  });
}

function prepare_policy_dialog() {
  $( '#scheduling_policy_dialog' ).dialog({
  	autoOpen: false,
		height: 200,
		width: 400,
		modal: true,
		buttons: {			},
		close: function() {
		}
	});
}

function prepare_general_purpose_dialog() {
  $( '#general_purpose_dialog' ).dialog({
		autoOpen: false,
		height: 200,
		width: 470,
		modal: true,
		buttons: {			},
		close: function() {
		}
	});
}

function prepare_add_vms_dialog() {
  $( '#add_vms_to_exp' ).dialog({
		autoOpen: false,
		height: 350,
		width: 450,
		modal: true,
		buttons: {			},
		close: function() {
		}
	});
}

function refresh_regression_tree_chart(id, moe_name, url_path) {
  element_id = "#busy_" + id + "_" + moe_name;
  chart_id = $("#infovis_"+id+"_"+moe_name).parent().parent().attr("id");
  $(element_id).show();
  $.ajax({
    url: url_path,
    data: "experiment_id=" + id + "&moe_name=" + moe_name + "&chart_id=" + chart_id,
      success: function(msg) { $(element_id).hide(); eval(msg) }
  });
}

function refresh_chart(id, moe_name, resolution, url_path) {
  element_id = "#busy_basic_" + id + "_" + moe_name + "_" + resolution;
  chart_id = $("#basic_chart_container_"+id+"_"+moe_name+"_"+resolution).parent().attr("id");
  $(element_id).show();
  $.ajax({
    url: url_path,
    data: "experiment_id=" + id + "&moe_name=" + moe_name + "&resolution=" + resolution + "&chart_id=" + chart_id,
      success: function(msg) { $(element_id).hide(); eval(msg) }
  });
}

function refresh_bivariate_chart(experiment_id, x_axis, y_axis, url_path) {
  container_id = "#bivariate_chart_container_" + x_axis + "_" + y_axis
  chart_id = $(container_id).parent().attr("id");

  busy_element_id = "#busy_bivariate_" + x_axis + "_" + y_axis;
  $(busy_element_id).show();
  $.ajax({
    url: url_path,
    data: "experiment_id=" + experiment_id + "&x_axis=" + x_axis + "&y_axis=" + y_axis + "&chart_id=" + chart_id,
      success: function(msg) { $(busy_element_id).hide(); eval(msg) }
  });
}

function add_live_validation(id, min, max) {
  vars[id] = new LiveValidation(id, { validMessage: 'OK' });
  vars[id].add(Validate.Numericality, { minimum: min, maximum: max });
}

function set_z_index(id) {
    var z_indexes = [$('#histogram_analysis_window').css("z-index"),
                     $('#rtree_analysis_window').css("z-index"),
                     $('#bivariate_analysis_window').css("z-index"),
                     $('#running_experiments_window').css("z-index"),
                     $('#available_experiments_window').css("z-index"),
                     $('#historical_experiments_window').css("z-index")];

    var largest_z_index = Math.max.apply(Math, z_indexes);
    $('#' + id).css("z-index", largest_z_index + 1);
}

function show_window(window_name) {
    if(window_name.match(/experiments$/)) {
        var element = $('#' + window_name + '_window');
    } else {
        var element = $('#' + window_name + '_analysis_window');
    }

    if(!element.hasClass(window_name + "_window_slide")) {
        element.removeClass(window_name + "_window_slide_out");
        element.addClass(window_name +  "_window_slide");

        element.css("top", "20px");
        element.css("bottom", "20px");
        if(window_name.match(/experiments$/)) {
            element.css("left", "auto");
        } else {
            element.css("right", "auto");
        }
    }

    if (window_name.match(/experiments$/)) {
        set_z_index(window_name + "_window");
    } else {
        set_z_index(window_name + "_analysis_window");
    }
}

function close_window(window_name) {
    if(window_name.match(/experiments$/)) {
        var element = $('#' + window_name + '_window');
    } else {
        var element = $('#' + window_name + '_analysis_window');
    }

    element.removeClass(window_name + "_window_slide");
    element.addClass(window_name + "_window_slide_out");

    element.css("top", "-120%")
    element.css("bottom", "-20px");
    if (window_name.match(/experiments$/)) {
        element.css("left", "-200%");
    } else {
        element.css("right", "-200%");
    }
}

function show_flash_error(error_msg) {
    $('div.error').html(error_msg);
    $('div.error').show();
    setTimeout(function() { $('div.error').hide(); }, 10000);
}
