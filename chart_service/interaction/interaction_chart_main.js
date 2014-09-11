function interaction_main(i, param1, param2, data) {
	console.log(data);
	var chart = new Highcharts.Chart({
		chart: {
			renderTo: $('#interaction_chart_'+i + " .chart")[0]
		},
		title: {
			text: "Interaction chart"
		},
		xAxis: {
			title: {
				text: param1
			}
		},
		yAxis: {
			title: {
				text: "Average effect"
			}
		},
		credits:{
			enabled: false
		},
		legend: {
			layout: 'vertical'
		},
		series: [{
			name: "Low " + param2,
			data: [{
				name: "Point 1",
				x: data[param1].domain[0],
				y: data.effects[0]
			}, {
				name: "Point 2",
				x: data[param1].domain[1],
				y: data.effects[1]
			}]
		}, {
			name: "High " + param2,
			data: [{
				name: "Point 3",
				x: data[param1].domain[0],
				y: data.effects[2]
			}, {
				name: "Point 4",
				x: data[param1].domain[1],
				y: data.effects[3]
			}]
		}]
	})
}