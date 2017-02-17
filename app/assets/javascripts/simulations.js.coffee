class window.PerformanceStats
  constructor: (@data) ->
    @data = JSON.parse(@data)
    @createCharts()

  createCharts: () ->
    @createCPUCharts()
    @createMemoryCharts()
    @createIOCharts()

  createCPUCharts: () ->
    Highcharts.chart 'cpu-stats',
      title:
        text: 'CPU-related performance statistics'
      yAxis:
        title:
          text: 'Time spent in user and kernel space or waiting for IO [ms]'
      xAxis:
        type:  'datetime'
      legend:
        layout: 'vertical',
        align: 'right',
        verticalAlign: 'middle'
      series: [{
        name: 'utime',
        data: ([ element.timestamp * 1000, element.utime ] for element in @data)
      }, {
        name: 'stime',
        data: ([ element.timestamp * 1000, element.stime ] for element in @data)
      }, {
        name: 'iowait',
        data: ([ element.timestamp * 1000, element.iowait ] for element in @data)
      }]

  createMemoryCharts: () ->
    Highcharts.chart 'memory-stats',
      title:
        text: 'Memory-related performance statistics'
      yAxis:
        title:
          text: 'Memory consumed over time [MB]'
      xAxis:
        type:  'datetime'
      legend:
        layout: 'vertical',
        align: 'right',
        verticalAlign: 'middle'
      series: [{
        name: 'RSS',
        data: ([ element.timestamp * 1000, element.rss / (1024 * 1024) ] for element in @data)
      }, {
        name: 'VMS',
        data: ([ element.timestamp * 1000, element.vms / (1024 * 1024) ] for element in @data)
      }, {
        name: 'Swap',
        data: ([ element.timestamp * 1000, element.swap / (1024 * 1024) ] for element in @data)
      }]

  createIOCharts: () ->
    Highcharts.chart 'io-counters-stats',
      title:
        text: 'IO-related performance statistics'
      yAxis:
        title:
          text: 'Read and write operations'
      xAxis:
        type:  'datetime'
      legend:
        layout: 'vertical',
        align: 'right',
        verticalAlign: 'middle'
      series: [{
        name: 'Read operations',
        data: ([ element.timestamp * 1000, element.read_count ] for element in @data)
      }, {
        name: 'Write operations',
        data: ([ element.timestamp * 1000, element.write_count ] for element in @data)
      }]

    Highcharts.chart 'io-stats',
      title:
        text: 'IO-related performance statistics'
      yAxis:
        title:
          text: 'Read and written bytes [MB]'
      xAxis:
        type:  'datetime'
      legend:
        layout: 'vertical',
        align: 'right',
        verticalAlign: 'middle'
      series: [{
        name: 'Read bytes',
        data: ([ element.timestamp * 1000, element.read_bytes / (1024 * 1024) ] for element in @data)
      }, {
        name: 'Write bytes',
        data: ([ element.timestamp * 1000, element.write_bytes / (1024 * 1024) ] for element in @data)
      }]
