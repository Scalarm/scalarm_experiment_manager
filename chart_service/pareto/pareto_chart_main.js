function pareto_main(i, data) {
	console.log(data);
	max = data.reduce(function(prev,cur){
		if(prev.value<cur.value) return cur;
		else return prev;
	})
	console.log(max);
	var chart = new Highcharts.Chart({
		chart: {
			renderTo: $('#pareto_chart_'+ i + " .chart")[0],
			type: 'bar'
		},
		title: {
			text: "Pareto chart"
		},
		xAxis: {
			categories: data.map(function(e){ return e.name;}),
			title: {
				text: "Parameters"
			}
		},
		yAxis: {
			min: 0,
			title: {
				text: "Average effect"
			},
			plotLines: [{
	            color: '#335577',
	            width: 2,
	            value: .8 * max.value,
	            dashStyle: "dash"
	        }]
		},
		credits: {
			enabled: false
		},
        legend: {
        	enabled: false
        },
		series: [{
			name: "Effect",
			data: data.map(function(e){ return e.value; })
		}]
	})
}