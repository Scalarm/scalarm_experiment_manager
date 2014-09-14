var DBURL = "mongodb://172.16.67.121:27017/scalarm_db";
var COLLECTION_NAME = "experiment_instances_";
var mongo = require('mongodb');
var client = mongo.MongoClient;
client.connect(DBURL, function(err, db){
	if (err) throw err;

	var mongo_fun = function(id, fun){
		// var client = require('mongodb').MongoClient;
		// client.connect(DBURL, function(err, db){
		// 	if(err) throw err;

			// var filter = {id: {'$lt':10}};

			db.collection(COLLECTION_NAME+id).find().toArray(function(err, array){
				if(err) throw err;

				var args_fullnamed = array[0].arguments.split(',');
				var args = args_fullnamed.map(function(arg){ 
					return arg.split('___').slice(-1)[0];
				});

				array = array.map(function(data){
					var values = data.values.split(',');

					var new_args = {};
					for(var i = 0; i<args.length; i++){
						new_args[args[i]] = parseInt(values[i]);
						// args.push({
						// 	name: arguments[i],
						// 	value: values[i]
						// });
					}

					data.arguments = new_args;
					delete data.values;

					return data;
				})

				var mins = [], maxes = [];
				for (i in args) {
					mins[args[i]] = min(array, args[i]);
					maxes[args[i]] = max(array, args[i]);
				}
				// db.close();
				fun(array,args,mins,maxes);

				// console.log("min population_size",mins[0]);
				// console.log("max population_size",maxes[0]);
				// console.log("min iteration_count",mins[1]);
				// console.log("max iteration_count",maxes[1]);

			});
		// });
	};

	var authenticate = function(userID, experimentID, success, error) {
		// var mongo = require('mongodb');
		// var client = mongo.MongoClient;
		// client.connect(DBURL, function(err, db){
			db.collection("experiments").find({$or : [
				{"_id": mongo.ObjectID(experimentID), "user_id": mongo.ObjectID(userID)}, 
				{"_id": mongo.ObjectID(experimentID), "shared_with" : {$in:[mongo.ObjectID(userID)]}}
			]}).toArray(function(err, array) {
				if(array.length>0) {
					success("OK!");
				}
				else {
					error("Access denied.");
				}
			});
		// });
	};

	var getParameters = function(experimentID, success, error) {
		// var mongo = require('mongodb');
		// var client = mongo.MongoClient;
		// client.connect(DBURL, function(err, db){
			// if (err) throw err;
			db.collection("experiments").find({"experiment_id": mongo.ObjectID(experimentID)}).toArray(function(err, array){
				if (err) throw err;
				if(array){
					var parameters = array[0]["experiment_input"][0]["entities"][0]["parameters"];
					parameters = parameters.map(function(param){
						return {
									label: param["label"],
									id:    param["id"]
							   };
					})
					success(parameters);
				}
				else{
					error("No such experiment")
				}
			})
		// })
	};

	var createStreamFor = function(connection, experimentID){
		// var client = require("mongodb").MongoClient;

		// client.connect(DBURL, function(err, db) {
			var stream = db.collection("capped_collection").find({date: {"$gte": new Date()/1000}, experiment_id: experimentID},
																 {tailable: true, awaitdata: true, numberOfRetries: -1}).stream();

			stream.on('data', function(item) {
				console.log(item);
				connection.send(JSON.stringify(item));
			});
			stream.on('error', function(error) {
				console.log("Error retrieving data from capped collection: " + error);
			})
			stream.on('close', function() {
				console.log("Unexpected stream close (capped collection)");
			})
		// });
	};

	var getPareto = function(id, callback){
		mongo_fun(id, function(array, args, mins, maxes){
			effects = [];
			effects.push(Math.abs(calculateAverage(array, args[0], maxes[args[0]])-calculateAverage(array, args[0], mins[args[0]])));
			effects.push(Math.abs(calculateAverage(array, args[1], maxes[args[1]])-calculateAverage(array, args[1], mins[args[1]])));
			var data = [];
			for(i in args) {
				data.push({
		 			name:  args[i],
		 			value: effects[i]
		 		});
		 	}
		 	callback(data);
		});
	};

	var getInteraction = function(id, param1, param2, callback, err){
	  mongo_fun(id, function(array, args, mins, maxes){
	  	var low_low=array.filter(function(obj) {
	  		return getValue(obj,param1) === mins[param1]
		}).filter(function(obj) { 
			return getValue(obj,param2) === mins[param2]
		})[0]; //TODO maybe calculate average of data in arrays?

		var low_high=array.filter(function(obj) {
			return getValue(obj,param1) === mins[param1]
		}).filter(function(obj) { 
			return getValue(obj,param2) === maxes[param2]
		})[0];

		var high_low=array.filter(function(obj) {
			return getValue(obj,param1) === maxes[param1]
		}).filter(function(obj) { 
			return getValue(obj,param2) === mins[param2]
		})[0];

		var high_high=array.filter(function(obj) {
			return getValue(obj,param1) === maxes[param1]
		}).filter(function(obj) { 
			return getValue(obj,param2) === maxes[param2]
		})[0];

		//TODO refactor
		if(!(low_low && low_high && high_low && high_high)) {
			err("There aren't all experiments!");
			return;
		}
		else {

			//console.log("low_low", low_low.result.distance);
			//console.log("low_high", low_high.result.distance);
			//console.log("high_low", high_low.result.distance);
			//console.log("high_high", high_high.result.distance);
		
			result = [];
			result.push(low_low.result.distance,
						low_high.result.distance, 
						high_low.result.distance, 
						high_high.result.distance)
			var data = {};
			data[param1] = {
				domain: [mins[param1], maxes[param1]]
			};
			data[param2] = {
				domain: [mins[param2], maxes[param2]]
			};
			data.effects = result;
			callback(data);
		}
	  })
	};

	module.exports.getPareto = getPareto;
	module.exports.getInteraction = getInteraction;
	module.exports.authenticate = authenticate;
	module.exports.getParameters = getParameters;
	module.exports.createStreamFor = createStreamFor;
});

var getValue = function(data, name){
	// console.log(data.arguments[name]);
	return data.arguments[name];
};

var min = function(array, name) {
    return array.reduce(function(a, b) { return a <= getValue(b,name) ? a : getValue(b,name);}, Infinity);
};

var max = function(array, name) {
    return array.reduce(function(a, b) { return a >= getValue(b,name) ? a : getValue(b,name);}, -Infinity);
};

function calculateAverage(data, parameter_name, parameter_value) {
	var array_of_params=data.filter(function(obj) {
		return getValue(obj, parameter_name) == parameter_value
	});
	var average = array_of_params.reduce(function(previous, current) {
		return previous + current.result.distance;
	}, 0) / array_of_params.length;
	return average;
};

