# TODO: translate tooltips (for .attr("title"...
class window.InfrastructuresTree
  constructor: (@baseSmDialogUrl, genericDialogId, @list_infrastructure_path,
                @simulation_manager_records_infrastructure_path, @simulation_manager_command_infrastructure_path) ->

    @bindRefreshTreeButton('refresh-button')

    @dialog = $("##{genericDialogId}")
    PROBE_INTERVAL = 30000

    # a map of functions for fetching and refreshing infrastructures sub-trees
    # infrastructure_name => function
    @fetchNodesFunctions = {}

    @root = null

    @m = [20, 80, 20, 80]
    @w = 1000 - @m[1] - @m[3]
    @h = 1000 - @m[0] - @m[2]
    @i = 0

    @tree = d3.layout.tree().size([@h, @w]);

    @circleRadius = 10

    @diagonal = d3.svg.diagonal().projection((d) -> [d.y, d.x])

    @vis = d3.select("#infrastructures-tree").append("svg:svg")
      .attr("width", @w + @m[1] + @m[3])
      .attr("height", @h + @m[0] + @m[2])
      .append("svg:g")
      .attr("transform", "translate(#{@m[3]}, #{@m[0]})");

    $.getJSON(@list_infrastructure_path, (data) =>
      @root = {"name": "Scalarm", "children": data}
      @root.x0 = @h / 2
      @root.y0 = 0;

      leaves = @tree.nodes(@root).filter((d) => d['infrastructure_name'])

      fetchUpdateNodes = (local_root, data) =>
        $.getJSON(@simulation_manager_records_infrastructure_path, data, (child_json) =>
          child_json = null if child_json.length == 0

          # Old code: Perform action only if node [is expanded or was not initialized before]
          # and when fetched children are not the same as in node
#          if not local_root['_children'] and not @childsEqual(local_root['children'], child_json)

          # Now - update when fetched children are not the same as in node
          if not @childsEqual(local_root['children'], child_json)
            if (local_root['children']) # is expanded
              local_root['children'] = child_json
            else # is collapsed
              local_root['_children'] = child_json

            child_json.forEach((child) =>
              child['infrastructure_name'] = local_root['infrastructure_name']
              child['group'] = local_root['group']
              child['type'] = 'sm-node'
            ) if child_json != null

            @updateTree(local_root);
        )

      leaves.forEach((leaf) =>
        leaf['type'] = 'sm-container-node'
        fetchLeafNodes = => fetchUpdateNodes(leaf, @smRecordsJson(leaf['infrastructure_name'], leaf['infrastructure_params']))
        fetchLeafNodes()
        setInterval(fetchLeafNodes, PROBE_INTERVAL)
        @fetchNodesFunctions[leaf['infrastructure_name']] = fetchLeafNodes
      )

      @updateTree(@root)
    )

  smRecordsJson: (name, params_hash) ->
    {'infrastructure_name': name, 'infrastructure_params': params_hash}

  # Compare children arrays: childs_local should be taken from current tree
  # childs_remote should be fetched from server.
  childsEqual: (childs_local, childs_remote) ->
    childs_local = null if typeof childs_local is 'undefined'

    if not childs_local? and not childs_remote?
      return true

    if (not childs_local? and childs_remote?) or (childs_local? and not childs_remote?) or (childs_local.length != childs_remote.length)
      return false

    # function for comparing nodes: name, sm_initialized
    node_hash_fun = (d) => [d.name, d.state].toString()
    array_a = childs_local.map(node_hash_fun).sort()
    array_b = childs_remote.map(node_hash_fun).sort()

    for i in [0..array_a.length]
      if (array_a[i] != array_b[i])
        return false

    true


  toggle: (d) ->
    if d.children
      d._children = d.children
      d.children = null
    else
      d.children = d._children
      d._children = null

  nodeStopSm: (d) ->
    @stopSm(d['infrastructure_name'], d['_id'])

  nodeRestartSm: (d) ->
    @restartSm(d['infrastructure_name'], d['_id'])

  nodeDestroyRecordSm: (d) ->
    @destroyRecordSm(d['infrastructure_name'], d['_id'])

  rebindCommandDialog: (infrastructure_name, record_id, command) ->
    $('#destroy-no').on 'click', =>
      $('#destroy_simulation_manager_dialog').foundation('reveal', 'close')

    $(".dialog-header").hide()
    $(".dialog-header##{command}-header").show()

    button = $('#destroy-yes')
    button.off()
    button.unbind()
    button.on 'click', =>
      $('#destroy_simulation_manager_dialog').foundation('reveal', 'close')
      window.show_loading_notice()
      data = { 'infrastructure_name': infrastructure_name, 'record_id': record_id, 'command': command }
      $.post(@simulation_manager_command_infrastructure_path, data, (json) =>
        @updateInfrastructureNode(infrastructure_name)
        window.hide_notice()
        switch json.status
          when 'error' then toastr.error(json.msg)
          when 'ok' then toastr.success(json.msg)
          else toastr.error(json.msg)
      )

  stopSm: (infrastructure_name, record_id) ->
    @rebindCommandDialog(infrastructure_name, record_id, 'stop')
    $('#destroy_simulation_manager_dialog').foundation('reveal', 'open')

  restartSm: (infrastructure_name, record_id) ->
    @rebindCommandDialog(infrastructure_name, record_id, 'restart')
    $('#destroy_simulation_manager_dialog').foundation('reveal', 'open')

  destroyRecordSm: (infrastructure_name, record_id) ->
    @rebindCommandDialog(infrastructure_name, record_id, 'destroy_record')
    $('#destroy_simulation_manager_dialog').foundation('reveal', 'open')

#  smCommand: (d, command) ->
#    data = { 'infrastructure_name': d['infrastructure_name'], 'record_id': d['_id'], 'command': command }
#    $.post(@simulation_manager_command_infrastructure_path, data,
#      (json) => @updateInfrastructureNode(d["infrastructure_name"]) # update infrastructure leaf
#    )

  updateTree: (source) ->
    duration = (d3.event && d3.event.altKey) and 5000 or 500

    # Compute the new tree layout.
    nodes = @tree.nodes(@root).reverse()

    # Normalize for fixed-depth.
    for d in nodes
      d.y = d.depth * 180

    # Update the nodes
    gNodes = @vis.selectAll("g.node")
      .data(nodes, (d) => (d.id || (d.id = ++@i)))

    # Enter any new nodes at the parent's previous position.
    gNodesEnter = gNodes.enter().append("svg:g")
      .attr("class", (d) => ["node", d.type].join(" "))
      .attr("transform", "translate(#{source.y0}, #{source.x0})")

    gs = gNodesEnter.append("svg:g")

    gMetaNodes = gs.filter((d) => d.type != 'sm-node')
    gSmNodes = gs.filter((d) => d.type == 'sm-node')
    gSmContainerNodes = gs.filter((d) => d.type == 'sm-container-node')

    # ---

    gMetaNodes.append("svg:circle")
      .attr("r", 1e-6)
      .attr("class", (d) => d._children and 'children-collapsed' or '')
      .on("click", (d) => @toggle(d); @updateTree(d))
    gMetaNodes.append("svg:text")
      .text((d) => @cutText(d.name, 18))
      .style("fill-opacity", 1e-6)
      .attr("title", (d) => d.name)
    # boost button
    gSmContainerNodes.append("svg:image")
      .attr("width", 16).attr("height", 16).attr("xlink:href", (d) => "/assets/plus_#{if d['enabled'] then '' else 'disabled_'}icon.png")
      .style("transform", "translate(12px,0px)")
      .attr("class", (d) => if d['enabled'] then "button" else '')
      .style("fill-opacity", 1e-6)
      .on("click", (d) => if d['enabled'] then @boosterDialog(d) else null)
      .attr("title", (d) => if d['enabled'] then "Increase computational power" else
        "This infrastructure is disabled for current user. Please check if credentials in user account settings are valid.")

    # ---

    gSmNodes.append("svg:g").call((g) =>
      g.append("svg:path")
        .attr("d", "m 0,0 12,12 210,0 0,-24 -210,0 z") # "label" path
        .attr("class", "sm-label")
        .style("fill-opacity", 1e-6)
        .attr("transform", "scale(1e-6)")

      g.append("svg:circle")
        .attr("r", 1e-6)
        .on("click", (d) => @smDialog(d))
        .attr("title", (d) =>
          # TODO: translation
          switch d.state
            when 'error' then 'An error occured for this Simulation Manager'
            when 'sm_initialized' then 'Simulation Manager is working'
            when 'before_init' then 'Simulation Manager waits for initialization'
            when 'terminating' then 'Simulation Manager waits for termination'
            else 'Unknown Simulation Manager state'
        )

      g.append("svg:text")
        .attr("class", "label-text")
        .text((d) => @cutText(d.name, 15))
        .style("fill-opacity", 1e-6)
        .style("transform", "translate(16px,4px)")
        .attr("title", (d) => d.name)


      # info button
      g.append("svg:image")
      .attr("width", 24).attr("height", 24).attr("xlink:href", '/assets/info_icon.png')
      .style("transform", "translate(140px,-12px)")
      .attr("class", "button")
      .on("click", (d) => @smDialog(d))
      .attr("title", "Show information about Simulation Manager")

      # restart button
      g.append("svg:image")
      .attr("width", 24).attr("height", 24).attr("xlink:href", '/assets/refresh_icon.png')
      .style("transform", "translate(166px,-12px)")
      .attr("class", "button")
      .on("click", (d) => @nodeRestartSm(d))
      .attr("title", "Restart Simulation Manager")

      # stop button
      g.append("svg:image")
      .attr("width", 24).attr("height", 24)
      .attr("xlink:href", (d) => '/assets/' + ((d.state == 'error' or d.state == 'terminating') and 'remove' or 'stop') + '_icon.png')
      .style("transform", "translate(192px,-12px)")
      .attr("class", "button")
      .on("click", (d) =>
        if d.state == 'error' or d.state == 'terminating'
          @nodeDestroyRecordSm(d)
        else
          @nodeStopSm(d)
      )
      .attr("title", (d) => (d.state == 'error' or d.state == 'terminating') and 'Remove Simulation Manager entry' or 'Stop Simulation Manager')

    )

    # Transition nodes to their new position.
    nodeUpdate = gNodes.transition()
      .duration(duration)
      .attr("transform", (d) => "translate(#{d.y}, #{d.x})")

    nodeUpdate.select("path")
      .style("fill-opacity", 1)
      .attr("transform", "scale(1)")

    nodeUpdate.select("circle")
      .attr("r", @circleRadius)
      .attr("class", @selectCircleClass)

    nodeUpdate.select("text")
      .style("fill-opacity", 1)

    nodeUpdate.select("image")
      .style("fill-opacity", 1)

    # Transition exiting nodes to the parent's new position.
    nodeExit = gNodes.exit().transition()
      .duration(duration)
      .attr("transform", (d) => "translate(#{source.y}, #{source.x})")
      .remove()

    nodeExit.select("path")
      .style("fill-opacity", 1e-6)
      .attr("transform", "scale(1e-6)")

    nodeExit.select("circle")
      .attr("r", 1e-6)

    nodeExit.select("text")
      .style("fill-opacity", 1e-6)

    # Update the links…
    link = @vis.selectAll("path.link")
      .data(@tree.links(nodes), (d) => d.target.id)

    # Enter any new links at the parent's previous position.
    link.enter().insert("svg:path", "g")
      .attr("class", "link")
      .attr("d", (d) =>
        o = {x: source.x0, y: source.y0}
        @diagonal({source: o, target: o})
      ).transition()
      .duration(duration)
      .attr("d", @diagonal)

    # Transition links to their new position.
    link.transition()
      .duration(duration)
      .attr("d", @diagonal)

    # Transition exiting nodes to the parent's new position.
    link.exit().transition()
      .duration(duration)
      .attr("d", (d) =>
        o = {x: source.x, y: source.y}
        @diagonal({source: o, target: o}))
      .remove()

    # Stash the old positions for transition.
    nodes.forEach((d) =>
      d.x0 = d.x
      d.y0 = d.y
    )

    null

  smDialog: (d) ->
    params = {infrastructure_name: d['infrastructure_name'], record_id: d['_id']}
    $.extend(params, {group: d['group']}) if d['group']
    @dialog.foundation('reveal', 'open')
    @dialog.html(window.loaderHTML)
    @dialog.load @smDialogPath(params)

  boosterDialog: (d) ->
    @dialog.foundation('reveal', 'open')
    @dialog.html(window.loaderHTML)
    @dialog.load @boosterDialogPath(d['infrastructure_name'], d['experiment_id'])

  commandConfirmDialog: (infrastructure_name, record_id) ->
    @dialog.foundation('reveal', 'open')
    @dialog.html(window.loaderHTML)
    @dialog.load @boosterDialogPath(d['infrastructure_name'], d['experiment_id'])


  smDialogPath: (params) ->
    "#{@baseSmDialogUrl}?" + $.param(params)

  boosterDialogPath: (infrastructure_name, experiment_id) ->
    # TODO: path as parameter
    "/infrastructure/get_booster_dialog?" + $.param({
      infrastructure_name: infrastructure_name,
      experiment_id: experiment_id
    })

  commandConfirmDialogPath: (infrastructure_name, record_id, command) ->
    "/infrastructure/get_command_confirm_dialog?" + $.param({
      infrastructure_name: infrastructure_name,
      experiment_id: experiment_id
    })

  cutText: (text, maxChars) ->
    if text.length > maxChars
      "#{text.substring(0, maxChars)}..."
    else
      text

  selectCircleClass: (d) ->
    if d.type == "sm-node"
      'sm-' + d.state
    else if d._children
      'children-collapsed'
    else
      ''

  bindRefreshTreeButton: (button_id) ->
    $("##{button_id}").on("click", =>
      @updateAllInfrastrctureNodes()
    )

  updateInfrastructureNode: (infrastructure_name) ->
    @fetchNodesFunctions[infrastructure_name]()

  updateAllInfrastrctureNodes: () ->
    for name, fun of @fetchNodesFunctions
      fun()
