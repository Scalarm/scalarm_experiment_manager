class window.InfrastructuresTree
  constructor: (@baseSmDialogUrl, genericDialogId) ->
    @dialog = $("##{genericDialogId}")
    PROBE_INTERVAL = 30000

    baseTreePath = "/infrastructures/tree"
    @root = null

    @m = [20, 80, 20, 80]
    @w = 1000 - @m[1] - @m[3]
    @h = 800 - @m[0] - @m[2]
    @i = 0

    @tree = d3.layout.tree().size([@h, @w]);

    @circleRadius = 10

    @diagonal = d3.svg.diagonal().projection((d) -> [d.y, d.x])

    @vis = d3.select("#infrastructures-tree").append("svg:svg")
      .attr("width", @w + @m[1] + @m[3])
      .attr("height", @h + @m[0] + @m[2])
      .append("svg:g")
      .attr("transform", "translate(#{@m[3]}, #{@m[0]})");

    d3.json(baseTreePath, (data) =>
      @root = data
      @root.x0 = @h / 2
      @root.y0 = 0;

      @updateTree(@root)

#      leaves = @findLeaves(@root)
      leaves = @tree.nodes(@root).filter((d) => d['type'] == 'sm-container-node')

      fetchUpdateNodes = (local_root, url) =>
        d3.json(url, (child_json) =>
          child_json = null if child_json.length == 0

          # Perform action only if node [is expanded or was not initialized before]
          # and when fetched children are not the same as in node
          if not local_root['_children'] and not @childsEqual(local_root['children'], child_json)
            if (local_root['children']) # is expanded
              local_root['children'] = child_json
            else # is collapsed
              local_root['_children'] = child_json

            child_json.forEach((child) =>
              child['sm_container'] = local_root['short']
            ) if child_json != null

            @updateTree(local_root);
        )

      leaves.forEach((leaf) =>
        fetchLeafNodes = => fetchUpdateNodes(leaf, @leafPath(leaf['short']))
        fetchLeafNodes()
        setInterval(fetchLeafNodes, PROBE_INTERVAL)
      )
    )

  leafPath: (name) ->
    "/infrastructures/sm_nodes?name=#{name}"

  # Compare children arrays: childs_local should be taken from current tree
  # childs_remote should be fetched from server.
  childsEqual: (childs_local, childs_remote) ->
    childs_local = null if typeof childs_local is 'undefined'

    if not childs_local? and not childs_remote?
      return true

    if (not childs_local? and childs_remote?) or (childs_local? and not childs_remote?) or (childs_local.length != childs_remote.length)
      return false

    names_array_fun = (d) => d.name
    array_a = childs_local.map(names_array_fun).sort()
    array_b = childs_remote.map(names_array_fun).sort()

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

# Old function for finding leaf nodes before fetching SM nodes.
# It is now defunctional and replaced by matching node types.
#  findLeaves: (local_root) ->
#    leaves = []
#    findLeaf = ((p) =>
#      if 'children' in p
#        p['children'].forEach((child) => findLeaf(child))
#      else
#        leaves.push(p))
#
#    findLeaf(local_root)
#    leaves

  stopSm: (d) ->
    url = "/infrastructures/stop_sm?sm_container=#{d['sm_container']}&resource_id=#{d['name']}"
    d3.json(url, (json) =>) # TODO use response

  restartSm: (d) ->
    url = "/infrastructures/restart_sm?sm_container=#{d['sm_container']}&resource_id=#{d['name']}"
    d3.json(url, (json) =>) # TODO use response

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
      .on("click", (d) => @toggle(d); @updateTree(d))

    gs = gNodesEnter.append("svg:g")

    gMetaNodes = gs.filter((d) => return d.type != 'sm-node')
    gSmNodes = gs.filter((d) => d.type == 'sm-node')

    # ---

    gMetaNodes.append("svg:circle")
      .attr("r", 1e-6)
      .attr("class", (d) => d._children and 'children-collapsed' or '')
    gMetaNodes.append("svg:text")
      .text((d) => d.name)
      .style("fill-opacity", 1e-6)

    # ---

    gSmNodes.append("svg:g").call((g) =>
      g.append("svg:path")
        .attr("d", "m 0,0 20,20 250,0 0,-40 -250,0 z") # "label" path
        .attr("class", "sm-label")
        .style("fill-opacity", 1e-6)
        .attr("transform", "scale(1e-6)")
      g.append("svg:circle")
        .attr("r", 1e-6)
        .attr("class", (d) => d._children and "children-collapsed" or "")
        .on("click", (d) => @smDialog(d))
      g.append("svg:text")
        .attr("class", "label-text")
        .text((d) => d.name)
        .style("fill-opacity", 1e-6)


      # info button
      g.append("svg:path")
      .attr("d", "M 5,0 C 2.2384,0 0,2.239067 0,5.000267 0,7.7616 2.2384,10 5,10 7.7616,10 10,7.7616 10,5.000267 10,2.239067 7.7616,0 5,0 z m 0.5101333,7.781333 c 0,0.096 -0.077867,0.173867 -0.1738666,0.173867 H 4.6637333 c -0.096,0 -0.1738666,-0.07773 -0.1738666,-0.173867 V 4.552267 c 0,-0.096 0.077867,-0.173867 0.1738666,-0.173867 h 0.6725334 c 0.096,0 0.1738666,0.07773 0.1738666,0.173867 v 3.229066 z m -0.5142666,-4.1236 c -0.3293334,0 -0.6024,-0.273066 -0.6024,-0.610533 0,-0.337333 0.2730666,-0.6024 0.6024,-0.6024 0.3374666,0 0.6105333,0.264933 0.6105333,0.6024 1.333e-4,0.337467 -0.2730667,0.610533 -0.6105333,0.610533 z")
      .style("transform", "translate(22px,0) scale(1.6)")
      .on("click", (d) => @stopSm(d))
      .attr("class", "info")
      .on("click", (d) => @smDialog(d))

      # restart button
      g.append("svg:path")
      .attr("d", "M 9.986427,0.989754 C 9.985427,0.910434 9.940087,0.836909 9.867315,0.801061 9.794695,0.764651 9.70749,0.771141 9.640932,0.817291 L 8.782754,1.418652 8.715184,1.466212 C 7.790449,0.564102 6.521229,0 5.114851,0 2.294442,0 0,2.243141 0,5 0,7.756859 2.294587,10 5.114851,10 6.815903,10 8.401454,9.176075 9.355787,7.795811 9.393757,7.740491 9.408047,7.67345 9.395057,7.608389 9.382067,7.543329 9.343517,7.485463 9.287207,7.448346 L 8.007592,6.580247 C 7.881984,6.498957 7.712629,6.530147 7.628168,6.652507 7.062499,7.46994 6.125202,7.957972 5.119615,7.957972 c -1.668712,0 -3.026435,-1.326916 -3.026435,-2.957689 0,-1.630772 1.357723,-2.957689 3.026435,-2.957689 0.704272,0 1.350215,0.239359 1.864487,0.635091 L 6.83958,2.7793 5.980825,3.380519 c -0.06569,0.04629 -0.100487,0.125607 -0.08822,0.204358 0.01169,0.07875 0.06786,0.145083 0.145532,0.170487 L 9.71196,4.978831 c 0.06656,0.02272 0.139468,0.01171 0.197508,-0.02865 0.05761,-0.04093 0.09081,-0.105425 0.09052,-0.173733 L 9.986418,0.989754 z")
      .style("transform", "translate(46px,0) scale(1.6)")
      .on("click", (d) => @restartSm(d))
      .attr("class", "restart")
      .on("click", (d) => @restartSm(d))

      # stop button
      g.append("svg:rect")
      .attr("width", 16).attr("height", 16).attr("rx", 1).attr("ry", 1)
      .attr("class", "stop")
      .style("transform", "translate(70px, 0)")
      .on("click", (d) => @stopSm(d))



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
      .attr("class", (d) => d._children and "children-collapsed" or "");

    nodeUpdate.select("text")
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
    @dialog.load @smDialogPath(d['sm_container'], d['name']), =>
#          @actionLoading.hide()
      @dialog.foundation('reveal', 'open')

  smDialogPath: (container, resource_id) ->
    "#{@baseSmDialogUrl}?sm_container=#{container}&resource_id=#{resource_id}"
