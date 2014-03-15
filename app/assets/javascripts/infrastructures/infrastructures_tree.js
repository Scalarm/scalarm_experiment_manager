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

    function fetch_nodes(local_root, url) {
        d3.json(url, function(child_json) {
            if (child_json.length == 0) {
                child_json = null
            }

            if (!local_root['_children'] && !childs_equal(local_root['children'], child_json)) {
                if (local_root['children']) {
                    local_root['children'] = child_json;
                } else {
                    local_root['_children'] = child_json;
                }
                update(local_root);
            }
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

            var fun = function() {fetch_nodes(leaf, url)};

            fun();
            setInterval(fun, 30000);
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
        var gNodes = vis.selectAll("g.node")
            .data(nodes, function(d) { return d.id || (d.id = ++i); });

        // Enter any new nodes at the parent's previous position.
        var gNodesEnter = gNodes.enter().append("svg:g")
            .attr("class", function(d) { return ["node", d.type].join(" ") })
            .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
            .on("click", function(d) { toggle(d); update(d); });

//        gNodesEnter.filter(function(x){return x.type != "sm-node"})

        var gs = gNodesEnter.append("svg:g");

        var gMetaNodes = gs.filter(function(d) {return d.type != 'sm-node'});
        var gSmNodes = gs.filter(function(d) {return d.type == 'sm-node'});

        // ---

        gMetaNodes.append("svg:circle")
            .attr("r", 1e-6)
            .attr("class", function(d) { return d._children ? "children-collapsed" : ""; });
        gMetaNodes.append("svg:text")
            .text(function(d) { return d.name; })
            .style("fill-opacity", 1e-6);

        // ---

        gSmNodes.append("svg:g").call(function(g) {
            g.append("svg:path")
                .attr("d", "m 0,0 30,30 250,0 0,-60 -250,0 z")
                .attr("class", "sm-label")
                .style("fill-opacity", 1e-6)
                .attr("transform", "scale(1e-6)");
            g.append("svg:circle")
                .attr("r", 1e-6)
                .attr("class", function(d) { return d._children ? "children-collapsed" : ""; });
            g.append("svg:text")
                .text(function(d) { return "NODE: " + d.name; })
                .style("fill-opacity", 1e-6);
        });



//        nodeEnter.append("svg:image")
//            .attr("xlink:href", "/assets/foundation-icons/fi-stop.svg")
//            .attr("width", 30).attr("height", 30);


//        nodeEnter.append("svg:path")
//            .attr("d", "m 12.071448,83.625893 0,-17.583621 15.227862,8.79181 15.227862,8.791811 -15.227861,8.79181 \
//                15.227863,8.791807 z m 0,33.840107 -177.786848,0 0,-67.68022 177.786848,0 z")
//            .attr("style", "fill:#ececec;fill-opacity:1;stroke:none");

        // Transition nodes to their new position.
        var nodeUpdate = gNodes.transition()
            .duration(duration)
            .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });

        nodeUpdate.select("path")
            .style("fill-opacity", 1)
            .attr("transform", "scale(1)");

        nodeUpdate.select("circle")
            .attr("r", circleRadius)
            .attr("class", function(d) { return d._children ? "children-collapsed" : ""; });

        nodeUpdate.select("text")
            .style("fill-opacity", 1);

        // Transition exiting nodes to the parent's new position.
        var nodeExit = gNodes.exit().transition()
            .duration(duration)
            .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
            .remove();

        nodeExit.select("path")
            .style("fill-opacity", 1e-6)
            .attr("transform", "scale(1e-6)");

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
