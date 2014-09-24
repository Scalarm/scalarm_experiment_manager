var jsdom = require("jsdom").jsdom();
var db_retriever = require("./data_retriever.js");

module.exports = function() {
    var map = {};
    map["/interaction"] = function(parameters, success, error){
        if(parameters["id"] && parameters["param1"] && parameters["param2"] && parameters["output"]){
            db_retriever.getInteraction(parameters["id"], 
                                        parameters["param1"], 
                                        parameters["param2"],
                                        parameters["output"], function(data) {
                var object = {};
                object.content = prepare_interaction_chart_content(parameters, data);
                success(object);
            }, error);
        }
        else
            error("Request parameters missing");
    }
    map["/pareto"] = function(parameters, success, error){
        if(parameters["id"]){
            db_retriever.getPareto(parameters["id"], function(data) {
                var object = {};
                object.content = prepare_pareto_chart_content(data);
                success(object);
            }, error);
        }
        else
            error("Request parameters missing");
    }
    return map;
}

function prepare_interaction_chart_content(parameters, data) {
    var output = "<script>(function() { \nvar i=" + parameters["chart_id"] + ";";
    output += "\nvar data = " + JSON.stringify(data) + ";";
    output += "\ninteraction_main(i, \"" + parameters["param1"] + "\", \"" + parameters["param2"] + "\", data);";
    output += "\n})();</script>";

    return output;
}

function prepare_pareto_chart_content(data) {
    var output = "<script>(function() {";
    output += "\nvar data = " + JSON.stringify(data) + ";";
    output += "\npareto_main(data);";
    output += "\n})();</script>";

    return output;
}