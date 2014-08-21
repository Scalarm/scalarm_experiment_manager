var jsdom = require("jsdom").jsdom();
var d3 = require("d3");
var db_retriever = require("../mongodb-data-retriever/data_retriever.js");

module.exports.prepare_interaction_chart = function(id, param1, param2, callback, err) {
    db_retriever.getInteraction(id, param1, param2, function(data) {
        callback(data);
    }, err)
}

module.exports.prepare_pareto_chart = function(id, callback) {
    db_retriever.getPareto(id, function(data) {
        // var data = [
        //     {name: "param1",
        //     value: 4},
        //     {name: "param2",
        //     value: 8},
        //     {name: "param3",
        //     value: 23},
        //     {name: "param4",
        //     value: 16},
        //     {name: "param5",
        //     value: 15},
        //     {name: "param6",
        //     value: 42}
        // ];

        data = data.sort(function(a,b){ return b.value-a.value})

        var max = d3.max(data, function(d) {
            return d.value;
        });

        //pre-rendering chart
        var content = jsdom.createElement("div");
        var svg = d3.select(content)
                    .append("svg")
                    .attr("width", w)
                    .attr("height", h);

        var xScale = d3.scale.linear()
                        .domain([0, max])
                        .range([0, 420]);
        // var yScale = d3.scale.ordinal()
        //                 .domain(["param1","param2","param3","param4","param5","param6"])
        //                 .rangeBands([0,100]);
        var xAxis = d3.svg.axis()
                        .scale(xScale)
                        .orient('bottom');
        // var yAxis = d3.svg.axis()
        //                 .scale(yScale)
        //                 .orient("left");

        var precolor = d3.scale.linear()
            .domain([0,max])
            .range([50, 200])

        var color = function(d){
            return Math.floor(precolor(d))
        };
        var barPadding = 3;



        svg.selectAll("rect")
           .data(data)
           .enter().append("rect")
           .attr("width", function(d) { return xScale(d.value); })
           .attr("height", 50)
           .attr('x', 20)
           .attr("y", function(d,i) { return i*(50+barPadding)+20;} )
           .attr('fill', function(d) { return 'rgb(75,75,'+color(d.value)+')';})
           .attr('stroke','black')
           .text(function(d) { return d.name; });

        svg.selectAll("text")
           .data(data)
           .enter()
           .append("text")
           .text(function(d) { return d.name})
           // .attr("text-anchor", "middle")
           .attr("alignment-baseline", "middle")
           .attr("x", function(d) { return xScale(d.value)+40})
           .attr("y", function(d,i) {return i*(50+barPadding)+20+25})

        svg.append('g')
            .call(xAxis)
            .attr('class','axis')
            .attr('transform','translate('+20+','+(20+data.length*(50+barPadding))+')')

        svg.append("text")
            .attr("transform", "translate("+(20+xScale(max/2))+','+(20+data.length*(50+barPadding)+40)+')')
            .attr("text-anchor", "middle")
            .text("Effect");
    

        //executing callback
        callback(content.innerHTML);
    })

}

module.exports.authenticate = function(userID, experimentID, success, error) {
    db_retriever.authenticate(userID, experimentID, function(data) {
        success(data);
    }, function(data) {
        error(data);
    });

}

function convertDataToArray(data, param) {
    var array = [];

    array.push([data[param]["domain"][0], data["effects"][0]]);
    array.push([data[param]["domain"][0], data["effects"][1]]);
    array.push([data[param]["domain"][1], data["effects"][2]]);
    array.push([data[param]["domain"][1], data["effects"][3]]);

    return array;
}
