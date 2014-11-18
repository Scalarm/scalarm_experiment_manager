var config = require("./config.js");
var dgram = require("dgram");
var client = dgram.createSocket("udp4");
var fs = require("fs");
var https = require("https");
var LBaddress;

module.exports.retrieveDBAddress = function(callback) {
    //wysluchac na multicascie adres
    //odczytac z tego adresu adres DB
    //wywolac callback(adresDB)

    client.bind(config.multicast_port);
    client.on("listening", function() {
        client.addMembership(config.multicast_address);
    });

    client.on("message", function(message, remote) {
        console.log("LB multicasted address: ", message.toString());
        if (LBaddress===undefined) {
            LBaddress = message.toString();
            var addressDB = "mongodb://172.16.67.30:27017/scalarm_db";
            console.log("Retrieved database address: ", addressDB);
            callback(addressDB);
        }
    })

};

module.exports.registerChartService = function(){
//    var data = querystring.stringify({
//        name: "ChartService",
//        address: config.server_ip + ":" + config.server_port
//    });
    var data = new Buffer("name=ChartService&address="+config.server_ip+":"+config.server_port);

    var options = {
        host: LBaddress,
        port: 443,
        path: "/register?"+data,
        method: "POST",
        rejectUnauthorized: false
//        agent: false
    };

    var post_req = https.request(options, function(response){
        response.on('data', function(chunk) {
            console.log(chunk.toString());
        })
    });
//    post_req.write(data);
    post_req.end();
};