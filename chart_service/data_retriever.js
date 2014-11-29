var DBURL = require("./config.js").db_url;
var COLLECTION_NAME = "experiment_instances_";
var mongo = require('mongodb');
var client = mongo.MongoClient;
var crypto = require('crypto');

var connect = function(success, error){
	client.connect(DBURL, function(err, db){
		if (err){
			error();
			return;
		}
		success();

		var getData = function(id, convertData, error){
			var filter = {is_done: true, is_error: {'$exists': false}};
			var fields = {fields: {arguments: 1, values: 1, result: 1}};

			db.collection(COLLECTION_NAME+id).find(filter, fields).toArray(function(err, array){
				if(err){
					error(err.toString());
					return;
				}
				if(array.length==0){
					error("No such experiment or no runs done");
					return;
				}

				var args = array[0].arguments.split(',');

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

                    for(var key in data.result){
                    	if(!Number.isNaN(parseFloat(data.result[key]))){
                        	data.result[key] = parseFloat(data.result[key]);
                        }
                    };

					return data;
				})

				var mins = [], maxes = [];
				for (var i in args) {
					mins[args[i]] = min(array, args[i]);
					maxes[args[i]] = max(array, args[i]);
				}
				
				convertData(array,args,mins,maxes);
			});
		};

		var checkIfExperimentVisibleToUser = function(userID, experimentID, success, error) {
            console.log("\tuserID: ", userID);
            console.log("\texperimentID: ", experimentID);
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
		};

        var checkUserAndPassword = function(username, password, success, error){
            db.collection('scalarm_users', function(err, collection){
                if(err){
                    error(err.toString());
                }
                else{
                    collection.findOne({login: username}, function(err, item){
                        if(err){
                            error(err.toString());
                            return;
                        }
                        else if(item) {
                            var salt = item.password_salt;
                            var hash = crypto.createHash('sha256').update(password+salt).digest('hex');
                            if(hash===item.password_hash){
                                success(item._id.toString());
                            }
                            else{
                                error("Wrong password\n");
                            }
                        }
                        else{
                            error("No such user\n");
                        }
                    })
                }
            })
        };

		var getParameters = function(experimentID, success, error) {
			var data = {};

			var filter = {is_done: true, is_error: {'$exists': false}};
			var fields = {fields: {result: 1}};

			db.collection(COLLECTION_NAME+experimentID, function(err, collection) {
				if(err){
					error(err.toString());
                    return;
				}
	        	collection.findOne(filter, fields, function(err, item) {
	        		data["result"] = [];
	        		if(item){
	        			for(var k in item.result){
	        				if(!Number.isNaN(parseFloat(item["result"][k]))){
                                data["result"].push({
                                    label: (k[0].toUpperCase() + k.slice(1)).split("_").join(" "),
                                    id: k
                                });
                            };
	        			};
	        		};
		            db.collection("experiments").findOne({"experiment_id": mongo.ObjectID(experimentID)}, function(err, doc){
						if (err) error(err.toString());
						if(doc){
                            data["parameters"] = [];
                            var experiment_input = doc["experiment_input"];
							for (var i in experiment_input){
                                var category = experiment_input[i];
                                var category_id = category["id"];
                                var category_label = category["label"];
                                var groups = category["entities"];
                                for (var j in groups){
                                    var group = groups[j];
                                    var group_id = group["id"];
                                    var group_label = group["label"];
                                    var parameters = group["parameters"];
                                    for(var k in parameters){
                                        var parameter = parameters[k];
                                        var parameter_id = parameter["id"];
                                        var parameter_label = parameter["label"];

                                        var labels = [category_label, group_label, parameter_label].filter(function(obj){return obj != undefined;});
                                        var ids = [category_id, group_id, parameter_id].filter(function(obj){return obj != undefined;});
                                        data["parameters"].push({
                                            label: labels.join(" - "),
                                            id: ids.join("___")
                                        });
                                    }
                                }
                            }

//                            //TODO - get parameters from all groups
//                            var parameters = array[0]["experiment_input"][0]["entities"][0]["parameters"];
//							data["parameters"] = parameters.map(function(param){
//								return {
//											label: param["label"],
//											id:    param["id"]
//									   };
//							})
							success(data);
						}
						else{
							error("No such experiment")
						}
					})
		        });
			   
		    });

			
		};

		var createStreamFor = function(connection, experimentID){
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
		};

		var getPareto = function(id, outputParam, success, error){
			getData(id, function(array, args, mins, maxes){
				effects = [];
				for(var i in args) {
					effects.push(Math.abs(calculateAverage(array, args[i], maxes[args[i]], outputParam)-calculateAverage(array, args[i], mins[args[i]], outputParam)));
				}
				var data = [];
				for(var i in args) {
					data.push({
			 			name:  args[i],
			 			value: effects[i]
			 		});
			 	}
			 	data.sort(function(a,b){ return b.value-a.value });
			 	success(data);
			}, error);
		};

		var getInteraction = function(id, param1, param2, outputParam, success, error){
		  	getData(id, function(array, args, mins, maxes){
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
					error("Not enough data in database!");
					return;
				}
				else {
				
					result = [];
					result.push(low_low.result[outputParam],
								low_high.result[outputParam], 
								high_low.result[outputParam], 
								high_high.result[outputParam])
					var data = {};
					data[param1] = {
						domain: [mins[param1], maxes[param1]]
					};
					data[param2] = {
						domain: [mins[param2], maxes[param2]]
					};
					data.effects = result;
					//console.log(data);
					success(data);
				}
			}, error);
		};

        var get3d = function(id, param1, param2, param3, success, error){
            getData(id, function(array, args, mins, maxes){
                var data = Array.apply(null, new Array(array.length)).map(Number.prototype.valueOf,0)
                if (args.indexOf(param1) != -1) {
                    for (var i in data) {
                        data[i] = [array[i].arguments[param1]];
                    }
                }
                else{
                    for (var i in data) {
                        data[i] = [array[i].result[param1]];
                        console.log(array[i].result[param1])
                    }
                }
                if (args.indexOf(param2) != -1) {
                    for (var i in data) {
                        data[i].push(array[i].arguments[param2]);
                    }
                }
                else{
                    for (var i in data) {
                        data[i].push(array[i].result[param2]);
                    }
                }
                if (args.indexOf(param3) != -1) {
                    for (var i in data) {
                        data[i].push(array[i].arguments[param3]);
                    }
                }
                else{
                    for (var i in data) {
                        data[i].push(array[i].result[param3]);
                    }
                }
                console.log(param1, param2, param3)
                success(data);
            }, error);
        }

		module.exports.getPareto = getPareto;
		module.exports.getInteraction = getInteraction;
        module.exports.get3d = get3d;
		module.exports.checkIfExperimentVisibleToUser = checkIfExperimentVisibleToUser;
		module.exports.getParameters = getParameters;
		module.exports.createStreamFor = createStreamFor;
        module.exports.checkUserAndPassword = checkUserAndPassword;
	});
}

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

function calculateAverage(data, parameter_name, parameter_value, outputParam) {
	var array_of_params=data.filter(function(obj) {
		return getValue(obj, parameter_name) == parameter_value
	});
	var average = array_of_params.reduce(function(previous, current) {
		return previous + current.result[outputParam];
	}, 0) / array_of_params.length;
	return average;
};

module.exports.connect = connect;

