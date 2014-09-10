var jsdom = require("jsdom").jsdom();
var d3 = require("d3");
var db_retriever = require("./data_retriever.js");


function prepare_chart(type, parameters, callback, err) {
    switch(type) {
        case "/interaction":
            db_retriever.getInteraction(parameters["id"], 
                                        parameters["param1"], 
                                        parameters["param2"], function(data) {
                var object = {};
                object.content = prepare_interaction_chart_content(parameters, data);
                callback(object);
            }, err);
            break;
        case "/pareto":
            db_retriever.getPareto(parameters["id"], function(data) {
                var object = {};
                object.content = prepare_pareto_chart_content(data);
                callback(object);
            }, err);
            break;
        default:
            err("WRONG!");
    }
}

function prepare_interaction_chart_content(parameters, data) {
    var output = "<script>(function() { \nvar i=" + parameters["chart_id"] + ";";
    output += "\nvar data = " + JSON.stringify(data) + ";";
    output += "\ninteraction_main(i, \"" + parameters["param1"] + "\", \"" + parameters["param2"] + "\", data);";
    output += "\ninteraction_interaction(i);";
    output += "\n})();</script>";

    return output;
}

function prepare_pareto_chart_content(data) {
    var output = "<script>(function() {";
    output += "\nvar data = " + JSON.stringify(data) + ";";
    output += "\npareto_main(data);";
    output += "\npareto_interaction();"
    output += "\n})();</script>";

    return output;
}

function authenticate(userID, experimentID, success, error) {
    db_retriever.authenticate(userID, experimentID, function(data) {
        success(data);
    }, function(data) {
        error(data);
    });

}

function convertDataToArray(data, param) {
    var array = [];

    array.push([data[param]["domain"][0], data["effects"][0]]);
    array.push([data[param]["domain"][0], data["effects"][1]]);
    array.push([data[param]["domain"][1], data["effects"][2]]);
    array.push([data[param]["domain"][1], data["effects"][3]]);

    return array;
}

function getParameters(experimentID, success, error){
    db_retriever.getParameters(experimentID, success, error);
}

module.exports.prepare_chart = prepare_chart;
module.exports.authenticate = authenticate;
module.exports.getParameters = getParameters;
