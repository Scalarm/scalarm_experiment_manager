var config = {
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
			description: "Shows significane of parameters (or interaction)"
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

module.exports = config;