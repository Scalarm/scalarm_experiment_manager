# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

class window.SimulationManagerUpdateHandler

  constructor: (@experimentId) ->
    @workers = []

  fullUpdate: () ->
    $.getJSON "/simulation_managers", (data) =>
      @workers = data.sm_records;
      @updateView()

  updateView: () =>
    @workersInStates = created: 0, initializing: 0, running: 0, terminating: 0, failed: 0
#    console.log @workers
    @workers.forEach (worker) =>
      workerState = worker.state

      if worker.experiment_id == @experimentId
        if workerState == "error"
          workerState = "failed"
        @workersInStates[workerState]++
#    console.log @workersInStates

    $("#state").empty()

    for stateName, workerCounter of @workersInStates
      if workerCounter != 0
        $("<li>").addClass("w-#{stateName}").text("#{workerCounter} #{stateName.toLowerCase()}").append("<br>").appendTo($("#state"))

    if @workersInStates["created"] == 0 && @workersInStates["initializing"] == 0 && @workersInStates["running"] == 0
      $("#workers_alert").show()
      $("#boostButton").addClass("success")
    else
      $("#workers_alert").hide()
      $("#boostButton").removeClass("success")

    $("#actions-loading-workers").hide()

  update: (notification) =>
    console.log notification

    @workers.forEach (worker, idx) =>
      if worker._id == notification.sim_id
        if notification.state == 'destroyed'
          @workers.splice(idx, 1)
        else
          worker.state = notification.state

    @updateView()
