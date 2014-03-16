class window.InfrastructuresTree
  constructor: ->
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
            ) if child_json = null

            @updateTree(local_root);
        )

      leaves.forEach((leaf) =>
        fetchLeafNodes = => fetchUpdateNodes(leaf, @leafPath(leaf['short']))
        fetchLeafNodes()
        setInterval(fetchLeafNodes, 3000)
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
    d3.json(url, (json) =>)

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
      g.append("svg:text")
        .attr("class", "label-text")
        .text((d) => d.name)
        .style("fill-opacity", 1e-6)

      stopGroup = g.append("svg:g").attr("class", "stop")
      stopGroup.append("svg:rect")
      .attr("width", 16).attr("height", 16).attr("rx", 1).attr("ry", 1)
      .attr("class", "stop")
      stopGroup.append("svg:text").attr("transform", "translate(26,0)").text("stop").attr("class", "stop")
      stopGroup.on("click", (d) => @stopSm(d))
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
