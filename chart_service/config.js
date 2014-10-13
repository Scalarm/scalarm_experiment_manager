var config = {
	server_ip: "localhost",
	server_port: 8080,
	server_prefix: "/chart",		//suffix?
	db_url: "mongodb://172.16.67.30:27017/scalarm_db"
}

var panel_config = {
	groups: [
	{
		id: "nasze_2",
		name: "Nasze 2",
		methods: [{
			name: "Interaction",
			id: "interactionModal",
			image: "https://placehold.it/117x71",
			description: "Shows interaction between 2 input parameters"
		},{
			name: "Pareto",
			id: "paretoModal",
			image: "https://placehold.it/117x71",
			description: "Shows significance of parameters (or interaction)"
		},{
			name: "3d scatter plot",
			id: "threeDModal",
			image: "https://placehold.it/117x71",
			description: "TODO"
		}]
		
	},
	{
		id: "pozostale",
		name: "Pozostałe",
		methods: [{
			name: "Histograms",
			id: "experiment-analysis-modal",
			em_class: "histogram-analysis",
			image: "https://placehold.it/117x71",
			description: "TODO"

		},{
			name: "Regression trees",
			id: "experiment-analysis-modal",
			em_class: "rtree-analysis",
			image: "https://placehold.it/117x71",
			description: "TODO"

		},{
			name: "Scatter plots",
			id: "experiment-analysis-modal",
			em_class: "bivariate-analysis",
			image: "https://placehold.it/117x71",
			description: "Bivariate analysis - scatter plot"

		}]
		
	}],
	pretty: true
};

module.exports.panel_config = panel_config;
module.exports.config = config;