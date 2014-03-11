function InfrastructuresTree() {

    var m = [20, 80, 20, 80],
        w = 1000 - m[1] - m[3],
        h = 800 - m[0] - m[2],
        i = 0;

    var circleRadius = 10;

    var tree = d3.layout.tree()
        .size([h, w]);

    var diagonal = d3.svg.diagonal()
        .projection(function(d) { return [d.y, d.x]; });

    var vis = d3.select("#infrastructures-tree").append("svg:svg")
        .attr("width", w + m[1] + m[3])
        .attr("height", h + m[0] + m[2])
        .append("svg:g")
        .attr("transform", "translate(" + m[3] + "," + m[0] + ")");

    function leaf_path(name) {
        return "/infrastructures/sm_nodes?name=" + name;
    }

    function fetch_tree(path) {
        d3.json(path, function(json) {
            update(json);
        });
    }

    var base_tree_path = "/infrastructures/tree";

    var root;

    d3.json(base_tree_path, function(data) {
        root = data;
        root.x0 = h / 2;
        root.y0 = 0;

        update(root);

        var leaves = find_leaves(root);

        leaves.forEach(function(leaf) {
            var url = leaf_path(leaf['short']);

            setInterval(function() {
                d3.json(url, function(child_json) {
                    if (child_json.length == 0) {
                        child_json = null
                    }

                    if (!leaf['_children'] && !childs_equal(leaf['children'], child_json)) {
                        if (leaf['children']) {
                            leaf['children'] = child_json;
                        } else {
                            leaf['_children'] = child_json;
                        }
                        update(leaf);
                    }
                });
            }, 30000);
        });

    });

    function childs_equal(childs_a, childs_b) {
        if (typeof childs_a == 'undefined') {
            childs_a = null;
        }
        if (!childs_a && !childs_a || !childs_a && childs_b || childs_a && !childs_b
            || childs_a.length !== childs_b.length) {
            return false;
        }

        var names_array_fun = function(d) {return d.name};
        var array_a = childs_a.map(names_array_fun).sort();
        var array_b = childs_b.map(names_array_fun).sort();

        for (var i=0, len=array_a.length; i<len; ++i) {
            if (array_a[i] !== array_b[i]) {
                return false;
            }
        }
        return true;
    }

    function has_children(p) {
        return p['_children'] || p['children'];
    }
    function is_collapsed(p) {
        return p['_children'] || !p['children'];
    }

    function update(source) {
        var duration = d3.event && d3.event.altKey ? 5000 : 500;

        // Compute the new tree layout.
        var nodes = tree.nodes(root).reverse();

        // Normalize for fixed-depth.
        nodes.forEach(function(d) { d.y = d.depth * 180; });

        // Update the nodes…
        var node = vis.selectAll("g.node")
            .data(nodes, function(d) { return d.id || (d.id = ++i); });

        // Enter any new nodes at the parent's previous position.
        var nodeEnter = node.enter().append("svg:g")
            .attr("class", function(d) { return "node " + d.type })
            .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
            .on("click", function(d) { toggle(d); update(d); });

        nodeEnter.append("svg:circle")
            .attr("r", 1e-6)
            .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });

        nodeEnter.append("svg:text")
            .text(function(d) { return d.name; })
            .style("fill-opacity", 1e-6);

        // Transition nodes to their new position.
        var nodeUpdate = node.transition()
            .duration(duration)
            .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });

        nodeUpdate.select("circle")
            .attr("r", circleRadius)
            .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });

        nodeUpdate.select("text")
            .style("fill-opacity", 1);

        // Transition exiting nodes to the parent's new position.
        var nodeExit = node.exit().transition()
            .duration(duration)
            .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
            .remove();

        nodeExit.select("circle")
            .attr("r", 1e-6);

        nodeExit.select("text")
            .style("fill-opacity", 1e-6);

        // Update the links…
        var link = vis.selectAll("path.link")
            .data(tree.links(nodes), function(d) { return d.target.id; });

        // Enter any new links at the parent's previous position.
        link.enter().insert("svg:path", "g")
            .attr("class", "link")
            .attr("d", function(d) {
                var o = {x: source.x0, y: source.y0};
                return diagonal({source: o, target: o});
            })
            .transition()
            .duration(duration)
            .attr("d", diagonal);

        // Transition links to their new position.
        link.transition()
            .duration(duration)
            .attr("d", diagonal);

        // Transition exiting nodes to the parent's new position.
        link.exit().transition()
            .duration(duration)
            .attr("d", function(d) {
                var o = {x: source.x, y: source.y};
                return diagonal({source: o, target: o});
            })
            .remove();

        // Stash the old positions for transition.
        nodes.forEach(function(d) {
            d.x0 = d.x;
            d.y0 = d.y;
        });
    }

    // Toggle children.
    function toggle(d) {
        if (d.children) {
            d._children = d.children;
            d.children = null;
        } else {
            d.children = d._children;
            d._children = null;
        }
    }

    function find_leaves(root) {
        var leaves = [];
        function find_leaf(p) {
            if ('children' in p) {
                p['children'].forEach(function(child) {find_leaf(child)});
            } else {
                leaves.push(p);
            }
        }
        find_leaf(root);
        return leaves
    }
}
