var data = require("./data_retriever");
// console.log(data.getInteraction('a'))
data.getPareto(function(data){console.log(data)})
data.getInteraction(function(data){console.log(data)})