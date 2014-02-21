# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

window.scalarm_objects = {}

class window.ExperimentSpeedometer

  constructor: (@experiment_id) ->
    @element_id = "speedometer_#{@experiment_id}"
    @interval = 60

  show: ->
    @prepare_speedometer()
    @update_speed()
    setInterval(
      => @update_speed()
    , @interval*1000)

  prepare_speedometer: ->
    @chart = new Highcharts.Chart({
            chart:
              renderTo: @element_id
              type: 'gauge'
              plotBackgroundColor: null
              plotBackgroundImage: null
              plotBorderWidth: 0
              plotShadow: false
              backgroundColor:'rgba(255, 255, 255, 0)'
            title:
              text: 'Experiment Speedometer'
            pane: {
                startAngle: -150,
                endAngle: 150,
                background: [{
                    backgroundColor: {
                        linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                        stops: [
                            [0, '#FFF'],
                            [1, '#333']
                        ]
                    },
                    borderWidth: 0,
                    outerRadius: '109%'
                }, {
                    backgroundColor: {
                        linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1 },
                        stops: [
                            [0, '#333'],
                            [1, '#FFF']
                        ]
                    },
                    borderWidth: 1,
                    outerRadius: '107%'
                }, {
                }, {
                    backgroundColor: '#DDD',
                    borderWidth: 0,
                    outerRadius: '105%',
                    innerRadius: '103%'
                }]
            },

            yAxis: {
                min: 0,
                max: 200,

                minorTickInterval: 'auto',
                minorTickWidth: 1,
                minorTickLength: 10,
                minorTickPosition: 'inside',
                minorTickColor: '#666',

                tickPixelInterval: 30,
                tickWidth: 2,
                tickPosition: 'inside',
                tickLength: 10,
                tickColor: '#666',
                labels: {
                    step: 2,
                    rotation: 'auto'
                },
                title: {
                    text: "#sim/min"
                },
#                plotBands: [{
#                    from: 0,
#                    to: 120,
#                    color: '#55BF3B'
#                }, {
#                    from: 120,
#                    to: 160,
#                    color: '#DDDF0D'
#                }, {
#                    from: 160,
#                    to: 200,
#                    color: '#DF5353'
#                }]
            },
            series: [{
                name: 'Speed',
                data: [0],
                tooltip:
                  valueSuffix: " simulations/#{@interval} secs"
            }],
        }
    )

  update_speed: ->
    speedometer = this

    $.getJSON "/experiments/#{@experiment_id}/completed_simulations_count?secs=#{@interval}", (resp_data) ->
      new_val = resp_data.count

      ymax = speedometer.chart.yAxis[0].max
      while(new_val > ymax)
        ymax *= 2
        speedometer.chart.yAxis[0].setExtremes(0, ymax)

      while((new_val < ymax / 4) && (ymax > 200))
        ymax /= 2
        speedometer.chart.yAxis[0].setExtremes(0, ymax)


      point = speedometer.chart.series[0].points[0]
      point.update(new_val)


class window.ExperimentMonitor

  constructor: (@experiment_id) ->
    @update_interval = 20
    @obj_id = "experiment_monitor_#{@experiment_id}"

    window.scalarm_objects[@obj_id] = this
    @schedule_update()

  update: ->
    monitor = this

    $.getJSON "/experiments/#{monitor.experiment_id}/experiment_stats", (data) -> monitor.update_statistics(data)
    $.getJSON "/experiments/#{monitor.experiment_id}/experiment_moes", (data) -> monitor.update_moes(data)

  progress_bar_listener: (event) =>
    if (window.event)
      x = window.event.pageX
    else
      x = event.clientX
    canvas = $('#exp_progress_bar_2')

    x -= canvas.offset().left

    cellWidth = canvas.width() / @cellCounter
    cellId = Math.floor((x / cellWidth) + 1) * @simsPerCell
    if @simsPerCell > 0
      randomNumber = Math.floor((Math.random()*@simsPerCell)) # 0..@simsPerCell - 1
      cellId -= randomNumber

    $('#extension-dialog').load("/experiments/#{@experiment_id}/simulations/#{cellId}")
    $('#extension-dialog').foundation('reveal', 'open')

  update_statistics: (statistics) =>
    $("#exp_all_counter").html(statistics.all.toString().with_delimeters())
    $("#exp_sent_counter").html(statistics.sent.toString().with_delimeters())
    $("#exp_done_counter").html(statistics.done_num.toString().with_delimeters())
    $("#exp_done_percentage_counter").html(statistics.done_percentage)

    bar_colors = eval(statistics.progress_bar)
    canvas = document.getElementById("exp_progress_bar_2")
    context = canvas.getContext("2d")
    part_width = canvas.width / bar_colors.length

    context.fillStyle = "rgb(255, 255, 255)"
    context.fillRect(0, 10, canvas.width, canvas.height - 10)

    @bar_cells = []
    @cellCounter = bar_colors.length
    @simsPerCell = Math.floor(statistics.all / bar_colors.length)

    for i in [0..bar_colors.length]
      context.fillStyle = if(bar_colors[i] == 0) then "#BDBDBD" else "rgb(0, #{bar_colors[i]}, 0)"

      if i == bar_colors.length - 1
        context.fillRect(part_width * i, 10, part_width, canvas.height - 10)
        @bar_cells.push([part_width * i, part_width * i + part_width])
      else
        context.fillRect(part_width * i, 10, part_width*0.95, canvas.height - 10)
        @bar_cells.push([part_width * i, part_width * i + part_width*0.95])

#   formating avg execution time
    if(statistics.avg_execution_time != undefined)
      hours = ''
      if statistics.avg_execution_time >= 3600
        hours = Math.floor(statistics.avg_execution_time / 3600)
        statistics.avg_execution_time -= hours*3600
        hours = "#{hours} [h]"
        minutes = '0 [m]'
        statistics.avg_execution_time = Math.round(statistics.avg_execution_time)
      else
        minutes = ''

      if statistics.avg_execution_time >= 60
        minutes = Math.floor(statistics.avg_execution_time / 60)
        statistics.avg_execution_time -= minutes * 60
        minutes = "#{minutes} [m]"
        statistics.avg_execution_time = Math.round(statistics.avg_execution_time)

      seconds = "#{statistics.avg_execution_time} [s]"

      $("#execution_time_avg").html("#{hours} #{minutes} #{seconds}")
      $("#avg_execution_time").show()
    if(statistics.predicted_finish_time != undefined)
      $("#predicted_finish_time").html(statistics.predicted_finish_time)
      $("#p_predicted_finish_time").show()

  generate_html: (parent_id) ->
    $("#experiment_progress_bar .content").append($('<canvas>').attr('id', 'exp_progress_bar_2'))

    canvas = document.getElementById("exp_progress_bar_2")
    canvas.addEventListener('mousedown', @progress_bar_listener, false)

    monitor = this

    $.getJSON "/experiments/#{monitor.experiment_id}/experiment_stats", (data) -> monitor.update_statistics(data)

  schedule_update: ->
    setTimeout("window.scalarm_objects['#{"experiment_monitor_#{@experiment_id}"}'].update()", 1000)
    setInterval("window.scalarm_objects['#{"experiment_monitor_#{@experiment_id}"}'].update()", @update_interval*1000)

  update_moes: (moes_info) ->
    $(".moe_list").each((i, select_element) ->
      selected_option = $(select_element).find(":selected").val()
      $(select_element).html(moes_info.moes)

      $(select_element).find("option").filter(() ->
        return $(this).val() == selected_option
      ).attr('selected', true)
    )

    $(".moes_and_params_list").each((i, select_element) ->
      selected_option = $(select_element).find(":selected").val()
      $(select_element).html(moes_info.moes_and_params)

      $(select_element).find("option").filter(() ->
        return $(this).val() == selected_option
      ).attr('selected', true)
    )

class window.ExperimentBooster
  constructor: (@dialog_element_id) ->
    @dialogElement = $("#" + @dialog_element_id)
    @accordion_element_id = 'booster_tabs'
    @accordionElement = $('#booster_tabs')
    @loading_id = 'loading-img'
    @loadingElement = $('#loading-img')

  initDialog: ->
    $("##{@dialog_element_id}").dialog({ autoOpen: false, height: 'auto', width: 650, modal: true, resizable: true })
    $("##{@accordion_element_id}").accordion( { heightStyle: 'content' } )
    $("##{@dialog_element_id}").css('overflow', 'hidden')
#    @loadInfrastructureInfo()

  openDialog: (url) ->
    $("##{@dialog_element_id}").remove()

    $.get(url, '',
      (data, textStatus, xhr) =>
        $('body').append(data);
        $("##{@dialog_element_id}").dialog({ autoOpen:true, height: 'auto', width: 550, modal: true, resizable: true })
        $('body').foundation()
    )

  afterSubmit: () ->
    $("##{@dialog_element_id}").dialog('close')
    $("##{@loading_id}").show()

  onSuccess: (msg) ->
    $("##{@loading_id}").hide()
    alert(msg)

  loadInfrastructureInfo: ->
    $.getJSON('/infrastructure/infrastructure_info',
      (resp) ->
        $('#private_info').text(resp.private)
        $('#plgrid_info').text(resp.plgrid)
        $('#amazon_info').text(resp.amazon)
    )

class window.WindowManager
  constructor: () ->
    #experiments windows
    $("#running_experiments_window .close_button").on 'click', => @close_window("running_experiments")

    $("#running_experiments_link, .running_experiments_link").on 'click', =>
      $('#running_experiments_window').load '/experiments/running_experiments', =>
        @show_window("running_experiments")
        $("#running_experiments_window .close_button").on 'click', => @close_window("running_experiments")
      false

    $("#available_experiments_window .close_button").on 'click', => @close_window("available_experiments")

    $("#available_experiments_link, .available_experiments_link").on 'click', =>
      $('#available_experiments_window').load '/simulations/simulation_scenarios', =>
        @show_window("available_experiments")
        $("#available_experiments_window .close_button").on 'click', => @close_window("available_experiments")
      false

    $("#historical_experiments_window .close_button").on 'click', => @close_window("historical_experiments")
    $("#historical_experiments_link, .historical_experiments_link").on 'click', =>
      $('#historical_experiments_window').load '/experiments/historical_experiments', =>
        @show_window("historical_experiments")
        $("#historical_experiments_window .close_button").on 'click', => @close_window("historical_experiments")
      false

    # analysis charts
    $("#histogram_analysis_link, .histogram_analysis_link").on 'click', =>
      @show_window('histogram_analysis')
      false
    $("#histogram_analysis_window .close_button").on('click', => @close_window('histogram_analysis'))

    $("#rtree_analysis_link, .rtree_analysis_link").on 'click', =>
      @show_window('rtree_analysis')
      false

    $("#rtree_analysis_window .close_button").on('click', => @close_window('rtree_analysis'))

    $("#bivariate_analysis_link, .bivariate_analysis_link").on 'click', =>
      @show_window("bivariate_analysis")
      false
    $("#bivariate_analysis_window .close_button").on('click', => @close_window("bivariate_analysis"))

  show_window: (window_name) =>
    element = $('#' + window_name + '_window')

    if(!element.hasClass(window_name + "_window_slide"))
      element.removeClass(window_name + "_window_slide_out")
      element.addClass(window_name +  "_window_slide")

      element.css("top", "20px");
      element.css("bottom", "20px");
      if(window_name.match(/experiments$/))
        element.css("left", "auto")
      else
        element.css("right", "auto")

    if (window_name.match(/experiments$/))
      @set_z_index(window_name + "_window")
    else
      @set_z_index(window_name + "_window")

  close_window: (window_name) ->
    element = $('#' + window_name + '_window')

    element.removeClass(window_name + "_window_slide")
    element.addClass(window_name + "_window_slide_out")

    element.css("top", "-120%")
    element.css("bottom", "-20px")

    if (window_name.match(/experiments$/))
      element.css("left", "-200%")
    else
      element.css("right", "-200%");

  set_z_index: (id) ->
    z_indexes = [$('#histogram_analysis_window').css("z-index"),
                 $('#rtree_analysis_window').css("z-index"),
                 $('#bivariate_analysis_window').css("z-index"),
                 $('#running_experiments_window').css("z-index"),
                 $('#available_experiments_window').css("z-index"),
                 $('#historical_experiments_window').css("z-index")]

    largest_z_index = Math.max.apply(Math, z_indexes)
    $('#' + id).css("z-index", largest_z_index + 1)


window.show_dialog_for_new_parameter_value = (parameter_id, parameter_label, url, experiment_id) ->
  $('#extensionDialogOpenButton').click()

  $('#extension-dialog').on 'extension-dialog-loaded', =>
    $('#extension-dialog #param_name').val(parameter_id)
    $('#extension-dialog #param_name').trigger('change')
