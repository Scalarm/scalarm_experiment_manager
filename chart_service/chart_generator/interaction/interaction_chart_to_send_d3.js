function interaction_to_send(i, param1, param2, data) {
	var w = $("#interaction_chart_" + i + " .chart")[0].offsetWidth,
	    h = 500,
	    padding = 30,
	    CIRCLE_RADIUS = 6;

	var xDomain = [],
        yDomain = [],
        tmp,
        svg = d3.select("#interaction_chart_" + i + " .chart")
                .append("svg")
                .attr("width", w)
                .attr("height", h);

    tmp = d3.extent(data[param1]["domain"]);
    xDomain[0] = tmp[0] - (tmp[1]-tmp[0])*0.1;
    xDomain[1] = tmp[1] + (tmp[1]-tmp[0])*0.1;
    var xScale = d3.scale.linear()
                    .domain(xDomain)
                    .range([padding, w-padding]);


    tmp = d3.extent(data["effects"]);
    yDomain[0] = tmp[0] - (tmp[1]-tmp[0])*0.1;
    yDomain[1] = tmp[1] + (tmp[1]-tmp[0])*0.1;
    var yScale = d3.scale.linear()
                    .domain(yDomain)
                    .range([h-padding, padding]);

    var xAxis = d3.svg.axis()
                    .scale(xScale)
                    .orient("bottom");

    var yAxis = d3.svg.axis()
                    .scale(yScale)
                    .orient("left")
                    // .tickFormat(d3.format("e"))
                    // .tickSize(5, 50);

    var convertedData = convertDataToArray(data, param1);

    svg.append("g")
        .attr("transform", "translate(0, " + (h - padding) + ")")
        .attr("class", "x axis")
        .call(xAxis);

    svg.append("g")
        .attr("transform", "translate(" + (padding) + ", 0)")
        .attr("class", "y axis")
        .call(yAxis);

    svg.append("line")
        .attr("x1", xScale(convertedData[0][0]))
        .attr("y1", yScale(convertedData[0][1]))
        .attr("x2", xScale(convertedData[2][0]))
        .attr("y2", yScale(convertedData[2][1]))
        .attr("class", "line_chart x1")
        .attr("data-legend", param2 + " HIGH")
        .attr("data-legend-color", "red")

    svg.append("line")
        .attr("x1", xScale(convertedData[1][0]))
        .attr("y1", yScale(convertedData[1][1]))
        .attr("x2", xScale(convertedData[3][0]))
        .attr("y2", yScale(convertedData[3][1]))
        .attr("class", "line_chart x2")
        .attr("data-legend", param2 + " LOW")
        .attr("data-legend-color", "blue")
    
    svg.selectAll("circle")
        .data(convertedData)
        .enter()
        .append("circle")
        .attr("cx", function(d) { return xScale(d[0]); })
        .attr("cy", function(d) { return yScale(d[1]); })
        .attr("r", function(d) { return CIRCLE_RADIUS; })
        .append("svg:title")
        .text(function(d) { return "(" + d + ")"; });

    svg.append("text")
        .attr("transform", "translate("+ (w/2) +","+(h)+")")
        .attr("text-anchor", "middle")
        .attr("id", param1+"_"+i)
        .text(param1);

    svg.append("text")
        .attr("transform", "translate("+ (padding/2) +","+(h/2)+")rotate(-90)")
        .attr("text-anchor", "middle")
        .attr("id", "AverageEffect_"+i)
        .text("Average effect");

    // svg.append("g")
    //    .attr("class","legend")
    //    .attr("transform","translate("+(0.75*w)+","+20+")")
    //    .style("font-size","12px")
    //    .call(d3.legend);
    onresizeHandler();

    window.addEventListener("resize", onresizeHandler);

    function onresizeHandler() {
        w = $("#interaction_chart_" + i + " .interaction_chart_container")[0].offsetWidth;
        // h = window.innerHeight - 50;
        svg
            .attr("width", w)
            .attr("height", h);

        xScale.range([padding, w-padding]); 


        svg.select(".y.axis")
            .transition()
            .call(yAxis);

        var bbox = d3.select(".y.axis")
                 .node()
                 .getBBox();
        d3.select(".y.axis")
          .attr("transform", "translate("+(padding+bbox.width)+", 0)");
        d3.select(".x.axis")
          .attr("transform", "translate("+bbox.width+"," +(h-padding)+ ")");
        xScale.range([padding+bbox.width, w-padding]);

        svg.select(".x.axis")
            // .transition()
            .attr("transform", "translate(0, " + (h - padding) + ")")
            .call(xAxis);

        svg.selectAll("circle")
            .data(convertedData)
            .transition()
            .attr("cx", function(d) { return xScale(d[0]); })
            .attr("cy", function(d) { return yScale(d[1]); })
            .attr("r", function() { return 3; });

        svg.select("line.x1")
            .transition()
            .attr("x1", xScale(convertedData[0][0]))
            .attr("y1", yScale(convertedData[0][1]))
            .attr("x2", xScale(convertedData[2][0]))
            .attr("y2", yScale(convertedData[2][1]));

        svg.select("line.x2")
            .transition()
            .attr("x1", xScale(convertedData[1][0]))
            .attr("y1", yScale(convertedData[1][1]))
            .attr("x2", xScale(convertedData[3][0]))
            .attr("y2", yScale(convertedData[3][1]));

        svg.select("#"+param1+"_"+i)
            .attr("transform", "translate("+ (w/2) +","+(h)+")")
            .attr("text-anchor", "middle")
            .text(param1);

        svg.select("#AverageEffect_"+i)
            .attr("transform", "translate("+ (padding/2) +","+(h/2)+")rotate(-90)")
            .attr("text-anchor", "middle")
            .text("Average effect");
    };
}

function convertDataToArray(data, param) {
    var array = [];

    array.push([data[param]["domain"][0], data["effects"][0]]);
    array.push([data[param]["domain"][0], data["effects"][1]]);
    array.push([data[param]["domain"][1], data["effects"][2]]);
    array.push([data[param]["domain"][1], data["effects"][3]]);

    return array;
}