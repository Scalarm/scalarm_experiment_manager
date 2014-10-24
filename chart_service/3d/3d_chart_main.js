function threeD_main(i, param1, param2, param3, data) {
    var min_z = data.reduce(function(a, b) { return a <= b[2] ? a : b[2];}, Infinity);
    var max_z = data.reduce(function(a, b) { return a >= b[2] ? a : b[2];}, -Infinity);

    function scale(z, min, max){
        return max-Math.round((z-min_z)/(max_z-min_z)*(max-min));
    }

    var tab = data.map(function(obj){
        var color = 'rgb(' + scale(obj[2], 109, 255) + ', ' + scale(obj[2], 66, 157) + ', ' + scale(obj[2], 30, 71) + ')';
        return {x: obj[0], y: obj[1], z: obj[2],
            color: color,
            marker: {
                states: {
                    hover: {
                        fillColor: color
                    }
                }
        }}});
    console.log(tab);

    //nice feature but causes "udefined is not a function" on loading more than one chart
    // Give the points a 3D feel by adding a radial gradient
    // Highcharts.getOptions().colors = $.map(Highcharts.getOptions().colors, function (color) {
    //     return {
    //         radialGradient: {
    //             cx: 0.4,
    //             cy: 0.3,
    //             r: 0.5
    //         },
    //         stops: [
    //             [0, color],
    //             [1, Highcharts.Color(color).brighten(-0.2).get('rgb')]
    //         ]
    //     };
    // });

    // Set up the chart
	var chart = new Highcharts.Chart({
        chart: {
            renderTo: $('#three_d_chart_'+ i + " .chart")[0],
            margin: 100,
            type: 'scatter',
            options3d: {
                enabled: true,
                alpha: 10,
                beta: 20,
                depth: 250,

                frame: {
                    bottom: { size: 1, color: 'rgba(0,0,0,0.02)' },
                    back: { size: 1, color: 'rgba(0,0,0,0.04)' },
                    side: { size: 1, color: 'rgba(0,0,0,0.06)' }
                }
            }
        },
        title: {
            text: '3d scatter plot'
        },
        subtitle: {
            text: param1 + " - " + param2 + " - " + param3
        },
        yAxis: {
            title: {
                text: param2
            }
        },
        xAxis: {
            title: {
                text: param1
            }
        },
        zAxis: {
            min: min_z,
            max: max_z,
            title: {
                text: param3
            }
        },
        credits: {
            enabled: false
        },
        legend: {
            enabled: false
        },
        series: [{
            data: tab
        }],
        tooltip: {
            formatter: function(){
                return param1 + ": " + this.x + "<br/>" + param2 + ": " + this.y + "<br>" + param3 + ": " + this.key;
            }
        }
    });


    // Add mouse events for rotation
    $(chart.container).bind('mousedown.hc touchstart.hc', function (e) {
        e = chart.pointer.normalize(e);

        var posX = e.pageX,
            posY = e.pageY,
            alpha = chart.options.chart.options3d.alpha,
            beta = chart.options.chart.options3d.beta,
            newAlpha,
            newBeta,
            sensitivity = 5; // lower is more sensitive

        $(document).bind({
            'mousemove.hc touchdrag.hc': function (e) {
                // Run beta
                newBeta = beta + (posX - e.pageX) / sensitivity;
                newBeta = Math.min(100, Math.max(-100, newBeta));
                chart.options.chart.options3d.beta = newBeta;

                // Run alpha
                newAlpha = alpha + (e.pageY - posY) / sensitivity;
                newAlpha = Math.min(100, Math.max(-100, newAlpha));
                chart.options.chart.options3d.alpha = newAlpha;

                chart.redraw(false);
            },
            'mouseup touchend': function () {
                $(document).unbind('.hc');
            }
        });
    });

}