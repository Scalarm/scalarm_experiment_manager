window.scalarm_objects = {}

class window.ExperimentSpeedometer

  constructor: (@experiment_id) ->
    @element_id = "speedometer_#{@experiment_id}"
    @interval = 60

    window.scalarm_objects[@element_id] = this

  show: ->
    @prepare_container()
    @prepare_speedometer()
    @update_speed()
    setInterval("window.scalarm_objects['#{@element_id}'].update_speed()", @interval*1000)

  prepare_container: ->
    $("article#experiment_stats").append($('<div>').attr('id', @element_id).addClass("speedometer"))

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

