var config = {
	server_ip: "172.16.67.121",
	server_port: 8080,
	server_prefix: "/chart",		//suffix?
	db_url: "mongodb://172.16.67.121:27017/scalarm_db"
}

var panel_config = {
	groups: [
	{
		id: "nasze_2",
		name: "Nasze 2",
		methods: [{
			name: "Interaction",
			id: "interactionModal",
			image: "http://placehold.it/117x71",
			description: "Shows interaction between 2 input parameters"
		},{
			name: "Pareto",
			id: "paretoModal",
			image: "http://placehold.it/117x71",
			description: "Shows significance of parameters (or interaction)"
		}],
		
	},
	{
		id: "pozostale",
		name: "Pozostałe",
		methods: [{
			name: "Bivariate analysis",
			id: "experiment-analysis-modal",
			image: "http://placehold.it/117x71",
			description: "Bivariate analysis - scatter plot"

		}]
		
	}],
	pretty: true
};

module.exports.panel_config = panel_config;
module.exports.config = config;