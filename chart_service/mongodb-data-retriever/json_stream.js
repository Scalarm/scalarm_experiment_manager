var fs = require("fs");
var stream = fs.createReadStream("tsp_on_amazon.json", {
	flags: 'r',
	encoding: 'utf-8',
	fd: null
});
var line;
var chunk_before = '';
var j = 1;
var data = [];

function min(array) {
	var min = Infinity;
	for(var i =0; i<array.length; i++) {
		if(min > array[i])
			min = array[i]
	}

	return min;
}

function max(array) {
	var max = 0;
	for(var i =0; i<array.length; i++) {
		if(max < array[i])
			max = array[i]
	}

	return max;
}

stream.addListener('data', function(line) {
	var array_of_inputs = line.split("\n");
	var before_array_of_inputs = array_of_inputs;
	var last_element = array_of_inputs[array_of_inputs.length-1];
	array_of_inputs = array_of_inputs.filter(function(data) {
		return data!="";
	});

	if(chunk_before!='') {
		array_of_inputs[0] = chunk_before+array_of_inputs[0];
	}

	//if last elements of 2 arrays are different => last element was ''
	if(last_element != array_of_inputs[array_of_inputs.length-1]) {
		chunk_before = '';
	}
	else {
		chunk_before = array_of_inputs[array_of_inputs.length-1];
		array_of_inputs.splice(array_of_inputs.length-1);
	}

	for(var i=0; i<array_of_inputs.length; i++) {
		// if(j%100===0 || j>1320 || j<=20) {
			// console.log(j, "", JSON.parse(array_of_inputs[i])["values"]);
			var values = JSON.parse(array_of_inputs[i])["values"];
			var distance = JSON.parse(array_of_inputs[i])["result"]["distance"];
			data.push({
						population_size: parseFloat(values.split(",")[0]),
					 	iteration_count: parseFloat(values.split(",")[1]),
					 	distance:        distance
					  });
		// }
		j++;
	}
});


stream.on("end", function() {

	calculateAverage_population_size(100);
	calculateAverage_population_size(780);
	calculateAverage_iteration_count(20);
	calculateAverage_iteration_count(390);

	var low_low=data.filter(function(obj) {
		return obj.population_size === 100
	}).filter(function(obj) { 
		return obj.iteration_count === 20
	})[0];

	var low_high=data.filter(function(obj) {
		return obj.population_size === 100
	}).filter(function(obj) { 
		return obj.iteration_count === 390
	})[0];

	var high_low=data.filter(function(obj) {
		return obj.population_size === 780
	}).filter(function(obj) { 
		return obj.iteration_count === 20
	})[0];

	var high_high=data.filter(function(obj) {
		return obj.population_size === 780
	}).filter(function(obj) { 
		return obj.iteration_count === 390
	})[0];

	console.log(low_low.distance, 
				low_high.distance, 
				high_low.distance, 
				high_high.distance);

	
	// console.log(population_size.sort(function(a,b) { return a-b }))
	// console.log(iteration_count.sort(function(a,b) { return a-b }))
	var population_size = data.map(function(value, index) { return value.population_size})
	var iteration_count = data.map(function(value, index) { return value.iteration_count});
	console.log("min population_size",min(population_size));
	console.log("max population_size",max(population_size));
	console.log("min iteration_count",min(iteration_count));
	console.log("max iteration_count",max(iteration_count));
	// console.log(data);

})

function calculateAverage_population_size(size) {
	var population_size_param=data.filter(function(obj) {
		return obj.population_size === size
	});
	var average = population_size_param.reduce(function(previous, current) {
		return previous + current.distance;
	}, 0) / population_size_param.length;

	console.log("Average population_size=" + size + ": ", average);
}

function calculateAverage_iteration_count(size) {
	var iteration_count_param=data.filter(function(obj) {
		return obj.iteration_count === size
	});
	var average = iteration_count_param.reduce(function(previous, current) {
		return previous + current.distance;
	}, 0) / iteration_count_param.length;

	console.log("Average iteration_count=" + size + ": ", average);
}

