var http = require("http");
var url = require("url");
var jsdom = require("jsdom").jsdom();
var fs = require("fs");
var querystring = require("querystring");
var exec = require("child_process").exec;

var decoder_configuration = require("./decoder_configuration.js");
	// options.secret_key_base = process.env.USER;	//we can set here secret_key_base
var cookieDecoder = require("cookieDecoder")(decoder_configuration);
var ChartService = require("./service.js");
var DataRetriever = require("./data_retriever.js");

var jade = require("jade");
var locals = require("./config.js");

var PORT = 8080,
	EXTERNAL_IP = "172.16.67.121",			//TODO - retrieve external IP
	ADDRESS = EXTERNAL_IP + "/chart";		//address suffix set in /etc/nginx/conf.d/default.conf

var app = http.createServer(function(req, res) {
	var parsedUrl = url.parse(req.url);
	var pathname = parsedUrl.pathname;
	var parameters = querystring.parse(parsedUrl.query);
	console.log("Pathname: " + pathname);
	console.log("Parameters: " + JSON.stringify(parameters));
	switch (pathname) {
		case "/panel":
			DataRetriever.getParameters(parameters["id"], function(data) {
				locals.parameters = data;
				locals.address = ADDRESS;
				res.writeHead(200);
				var panel = jade.renderFile("panel.jade", locals);
				res.write(panel);
				res.end();
			},
			function(err) {
				res.writeHead(404);
				res.write("Error getting parameters\n");
				res.write(err+"\n");
				res.end();
			})
			break;
		default:
			var share_image_pattern = /^\/images\/(.+)$/;
			if(share_image_pattern.test(pathname)) {
				var file = share_image_pattern.exec(pathname)[1];
				fs.readFile('.'+pathname, function(error, data) {
					if(error) {
						res.writeHead(404);
						res.write("File " + file_path + " : not found!\n");
						res.write(error.toString());
						res.end();
					}
					else {
						res.writeHead(200);
						res.write(data);
						res.end();
					}
				});
				return;

			}
			var url_pattern = /^\/(\w+)\/(main|interaction|style)$/;
			var scripts_pattern = /^\/(\w+)\/scripts$/;
			//when URL matches
			if(url_pattern.test(pathname)) {
				var groups_from_regexp = url_pattern.exec(pathname).slice(-2);
				var type = groups_from_regexp[0];
				var resource = groups_from_regexp[1];

				var file_path = type+"/"+type+"_chart_"+resource;
				file_path += resource==="style" ? ".css" : ".js";

				fs.readFile(file_path, function(error, data) {
					if(error) {
						res.writeHead(404);
						res.write("File " + file_path + " : not found!\n");
						res.write(error.toString());
						res.end();
						return;
					}
					else {
						res.writeHead(200);
						res.write(data);
						res.end();
						return;
					}
				});
			}
			else if(scripts_pattern.test(pathname)) {
				var groups_from_regexp = scripts_pattern.exec(pathname).slice(-1);
				// console.log(groups_from_regexp);
				var chart_type = groups_from_regexp[0];
				var tags = prepare_script_and_style_tags("/"+chart_type);

				res.writeHead(200);
				res.write(tags.script_tag_main);
				// res.write(tags.script_tag_interaction);
				// res.write(tags.style_tag);
				res.end();
			}
			else{
				//ChartMap
				var ChartMap = require("./new_service_conception-map.js")(function(object) { 			//function if successfully created OBJECT
					authenticate(req.headers.cookie, parameters["id"], function(data) {
						console.log("OK! Successfully authorized.");
						res.writeHead(200, {'Content-Type': 'text/plain'});
						//TODO - what with locals specific for chart? object.locals from service?
						var output = jade.renderFile("."+pathname+pathname+"Chart.jade", { chart_id: parameters["chart_id"], param1: parameters["param1"], param2: parameters["param2"]});
						// console.log(output);
						output += object.content;
						res.write(output);
						res.end();
					}, function(err) {
						console.log("FAILED! Sending info about error to Scalarm... \n" + err);
						//res.writeHead(..); ??
						res.write("Unable to authenticate");
						res.end();
					});
				}, function(err) {
					res.write(err);
					res.end();
				});
				if(ChartMap[pathname]){
					ChartMap[pathname](parameters);
				}
				else {
					//when URL doesn't match => incorrect request
					res.writeHead(404);
					res.write(pathname + " : incorrect request!");
					res.end();
				}

				// ChartService.prepare_chart(pathname, parameters, function(object) { 			//function if successfully created OBJECT
				// 	authenticate(req.headers.cookie, parameters["id"], function(data) {
				// 		console.log("OK! Successfully authorized.");
				// 		res.writeHead(200, {'Content-Type': 'text/plain'});
				// 		var output = jade.renderFile("."+pathname+pathname+"Chart.jade", { chart_id: parameters["chart_id"]});
				// 		// console.log(output);
				// 		output += object.content;
				// 		res.write(output);
				// 		res.end();
				// 	}, function(err) {
				// 		console.log("FAILED! Sending info about error to Scalarm... \n" + err);
				// 		//res.writeHead(..); ??
				// 		res.write("Unable to authenticate");
				// 		res.end();
				// 	});
				// }, function(err) {
				// 	if(err){
				// 		res.write(err);
				// 		res.end();
				// 		return;
				// 	}
				// 	//when URL doesn't match => incorrect request
				// 	res.writeHead(404);
				// 	res.write(pathname + " : incorrect request!");
				// 	res.end();
				// });
			}
	}
})
DataRetriever.connect(function(){
	app.listen(PORT, function(){
		console.log(new Date() + " Listening on port " + PORT);
	});
}, function(){
	console.log("Connection to database failed");
	throw new Error("Connection to database failed");
})

var WebSocketServer = require('websocket').server;
wsServer = new WebSocketServer({
	httpServer: app
})

wsServer.on('request', function(request) {
	//TODO -- authentication!
	console.log(new Date() + " Connection from origin " + request.origin + ".");
	console.log(request.httpRequest.headers.cookie);
	var experimentID = request.httpRequest.url.slice(1);
	authenticate(request.httpRequest.headers.cookie, experimentID, function(data) {
		console.log("OK! Successfully authorized.");
		var connection = request.accept(null, request.origin);
		console.log(new Date() + " Connection accepted.");

		connection.on('close', function(connection) {
	        console.log(new Date() + " Connection closed");
	        //TODO - close cursor?
	    });

		DataRetriever.createStreamFor(connection, experimentID);
	}, function(err) {
		console.log("Authentication failed! \n" + err);
	});
});

//--------------------------------
function authenticate(cookie, experimentID, success, error){
	//what if there are more cookies??
	var cookieGood = cookie.substr(17, cookie.length); //MAGIC NUMBER! :D (just for remove _scalarm_session= from the beginning)
	var output = cookieDecoder(cookieGood);

	exec("ruby serialized_object_to_json.rb " + new Buffer(output).toString("base64"), function(err, stdout, stderr) {
	    if (err !== null) {
	    	console.log('stderr: ' + stderr);
	    	console.log('exec error: ' + err);
	    	error(err);
	    	return;
	    }

		var userID = JSON.parse(stdout)["user"];
		console.log("\tuserID: ", userID); 
		console.log("\texperimentID: ", experimentID);

		DataRetriever.authenticate(userID, experimentID, function(dataSuccess) {
			success(dataSuccess);
		}, function(dataError) {
			error(dataError);
		});
	});
}

function prepare_script_and_style_tags(typeOfChart) {
	var tags = {};
	tags.script_tag_main = jsdom.createElement("script");
	tags.script_tag_main.setAttribute("type", "text/javascript");
	tags.script_tag_main.setAttribute("src","//" + ADDRESS + typeOfChart+"/main");

	// tags.script_tag_interaction = jsdom.createElement("script");
	// tags.script_tag_interaction.setAttribute("type", "text/javascript");
	// tags.script_tag_interaction.setAttribute("src", "//" + ADDRESS + typeOfChart+"/interaction");

	// tags.style_tag = jsdom.createElement("link");
	// tags.style_tag.setAttribute("href", "//" + ADDRESS + typeOfChart+"/style");
	// tags.style_tag.setAttribute("rel", "stylesheet");
	// tags.style_tag.setAttribute("type", "text/css");

	for(var prop in tags) {
		tags[prop] = tags[prop].outerHTML;
	}

    return tags;
}
