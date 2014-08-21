var http = require("http");
var url = require("url");
var jsdom = require("jsdom").jsdom();
var fs = require("fs");
var querystring = require("querystring");
var exec = require("child_process").exec;

var decoder_configuration = require("./decoder_configuration.js");
	// options.secret_key_base = process.env.USER;	//we can set here secret_key_base
var cookieDecoder = require("./cookies_decoder.js")(decoder_configuration);
var ChartService = require("./service.js");

var d3_cdn_path = "//cdnjs.cloudflare.com/ajax/libs/d3/3.4.11/d3.js",
	PORT = 8080,
	EXTERNAL_IP = "172.16.67.121",			//TODO - retrieve external IP
	ADDRESS = EXTERNAL_IP + "/chart",		//address suffix set in /etc/nginx/conf.d/default.conf
	url_to_file_map = {
		"/interaction/interaction" : "interaction/interaction_chart_interaction.js",
		"/interaction/to_send" : "interaction/interaction_chart_to_send.js",
		"/interaction/style" : "interaction/interaction_chart_style.css",
		"/pareto/interaction" : "pareto/pareto_chart_interaction.js",
		"/pareto/to_send" : "pareto/pareto_chart_to_send.js",
		"/pareto/style" : "pareto/pareto_chart_style.css",
	};

var app = http.createServer(function(req, res) {

	var parsedUrl = url.parse(req.url);
	var pathname = parsedUrl.pathname;
	var parameters = querystring.parse(parsedUrl.query);
	
	if(pathname==="/interaction") {
		authenticate(req.headers.cookie, parameters["id"], function(data) {
			console.log("SUCCESS! Sending to Scalarm chart... " + data);
			ChartService.prepare_interaction_chart(parameters["id"],
							      parameters["param1"],
							      parameters["param2"], 
							      function(data) {
				var tags = prepare_script_and_style_tags("/interaction");
				res.writeHead(200, {'Content-Type': 'text/plain'});
				if(parameters["func_defined"]==='false') {
					res.write(tags.script_tag_to_send);
					res.write(tags.script_tag_interaction);
					res.write(tags.style_tag);
				}
				res.write("<script>(function() { \nvar i=" + parameters["chart_id"] + ";");
				res.write("\nvar data = " + JSON.stringify(data) + ";");
				res.write("\ninteraction_to_send(i, \"" + parameters["param1"] + "\", \"" + parameters["param2"] + "\", data);");
				res.write("\ninteraction_interaction(i);");
				res.write("})();</script>");
				// res.write(tags.script_tag_d3_cdn); 	Scalarm has d3.js library
				res.end();
			}, function(error) {
				res.writeHead(200);
				res.write(error);
				res.end();
			});
		}, function(data) {
			console.log("FAILED! Sending info about error to Scalarm... " + data);
			res.write("Problem with: " + data);
			res.end();
		});

	}
	else if(pathname==="/pareto") {
		// authenticate(req.headers.cookie,parameters["id"]);

		ChartService.prepare_pareto_chart(parameters["id"], function(htmlChart) {
			var tags = prepare_script_and_style_tags("/pareto");

			res.writeHead(200, {'Content-Type': 'text/plain'});
			res.write(tags.script_tag_d3_cdn);
			res.write(tags.script_tag_to_send);
			res.write(tags.script_tag_interaction);
			res.write(tags.style_tag);
			res.write(htmlChart);
			res.end();
		});
	}
	else if(pathname in url_to_file_map){
		res.writeHead(200, {'Content-Type' : 'text/javascript'});
		fs.readFile(url_to_file_map[pathname], function(error, data) {
			if(error) 
				throw error;
			res.write(data);
			res.end();
		});
	}
	else {
		res.writeHead(404);
		res.write(pathname + " : not found!");
		res.end();

	}
}).listen(PORT);



function prepare_script_and_style_tags(typeOfChart) {
	var tags = {};
	tags.script_tag_to_send = jsdom.createElement("script");
	tags.script_tag_to_send.setAttribute("type", "text/javascript");
	tags.script_tag_to_send.setAttribute("src","//" + ADDRESS + typeOfChart+"/to_send");

	tags.script_tag_interaction = jsdom.createElement("script");
	tags.script_tag_interaction.setAttribute("type", "text/javascript");
	tags.script_tag_interaction.setAttribute("src", "//" + ADDRESS + typeOfChart+"/interaction");

	tags.script_tag_d3_cdn = jsdom.createElement("script");
	tags.script_tag_d3_cdn.setAttribute("type", "text/javascript");
	tags.script_tag_d3_cdn.setAttribute("src", d3_cdn_path);

	tags.style_tag = jsdom.createElement("link");
	tags.style_tag.setAttribute("href", "//" + ADDRESS + typeOfChart+"/style");
	tags.style_tag.setAttribute("rel", "stylesheet");
	tags.style_tag.setAttribute("type", "text/css");

	for(var prop in tags) {
		tags[prop] = tags[prop].outerHTML;
	}

    return tags;
}

//-----------------
function authenticate(cookie, experimentID, success, error){
	var cookieGood = cookie.substr(17, cookie.length); //MAGIC NUMBER! :D (just for remove _scalarm_session= from the beginning)
	var output = cookieDecoder(cookieGood);

	exec("ruby serialized_object_to_json.rb " + new Buffer(output).toString("base64"), function(errorExec, stdout, stderr) {
		var userID = JSON.parse(stdout)["user"];
		console.log("\tuserID: ", userID); 
		console.log("\texperimentID: ", experimentID);

		ChartService.authenticate(userID, experimentID, function(dataSuccess) {
			success(dataSuccess);
		}, function(dataError) {
			error(dataError);
		});
	});
}
