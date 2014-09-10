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

var jade = require("jade");
var locals = require("./config.js");

var d3_cdn_path = "//cdnjs.cloudflare.com/ajax/libs/d3/3.4.11/d3.js",
	PORT = 8080,
	EXTERNAL_IP = "172.16.67.121",			//TODO - retrieve external IP
	ADDRESS = EXTERNAL_IP + "/chart";		//address suffix set in /etc/nginx/conf.d/default.conf

var app = http.createServer(function(req, res) {
	var parsedUrl = url.parse(req.url);
	var pathname = parsedUrl.pathname;
	var parameters = querystring.parse(parsedUrl.query);
	console.log("Pathname: " + pathname);
	switch (pathname) {
		case "/panel":
			ChartService.getParameters(parameters["id"], function(data) {
				locals.parameters = data;
				res.writeHead(200);
				res.write(jade.renderFile("panel.jade", locals));
				res.end();
			},
			function(err) {

			})
			
			
			break;
		//temporary -- TODO
		case "/loading.gif":
			fs.readFile('./images/loading.gif', function(error, data) {
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
			break;
		default:
			ChartService.prepare_chart(pathname, parameters, function(object) { 			//function if successfully created OBJECT
				authenticate(req.headers.cookie, parameters["id"], function(data) {
					console.log("OK! Successfully authorized.");
					res.writeHead(200, {'Content-Type': 'text/plain'});
					var output = jade.renderFile("."+pathname+pathname+"Chart.jade", { chart_id: parameters["chart_id"]});
					output += object.content;
					res.write(output);
					// res.write(tags.script_tag_d3_cdn); 	Scalarm has d3.js library
					res.end();
				}, function(data) {
					console.log("FAILED! Sending info about error to Scalarm... " + data);
					res.write("Problem with: " + data);
					res.end();
				});
			}, function() {														//function when Scalarm makes request about scripts/stylesheets
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
						}
						else {
							res.writeHead(200);
							res.write(data);
							res.end();
						}
					});
				}
				else if(scripts_pattern.test(pathname)) {
					var groups_from_regexp = scripts_pattern.exec(pathname).slice(-1);
					console.log(groups_from_regexp);
					var type = groups_from_regexp[0];
					var tags = prepare_script_and_style_tags("/"+type);

					res.writeHead(200);
					res.write(tags.script_tag_main);
					res.write(tags.script_tag_interaction);
					res.write(tags.style_tag);
					res.end();
				}
				//when URL doesn't match => incorrect request
				else {
					res.writeHead(404);
					res.write(pathname + " : incorrect request!");
					res.end();
				}
			});
	}
}).listen(PORT);

//--------------------------------
function authenticate(cookie, experimentID, success, error){
	//what if there are more cookies??
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

function prepare_script_and_style_tags(typeOfChart) {
	var tags = {};
	tags.script_tag_main = jsdom.createElement("script");
	tags.script_tag_main.setAttribute("type", "text/javascript");
	tags.script_tag_main.setAttribute("src","//" + ADDRESS + typeOfChart+"/main");

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
