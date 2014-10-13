module.exports = {
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
                name: "Histograms",
                id: "experiment-analysis-modal",
                em_class: "histogram-analysis",
                image: "http://placehold.it/117x71",
                description: "TODO"

            },{
                name: "Regression trees",
                id: "experiment-analysis-modal",
                em_class: "rtree-analysis",
                image: "http://placehold.it/117x71",
                description: "TODO"

            },{
                name: "Scatter plots",
                id: "experiment-analysis-modal",
                em_class: "bivariate-analysis",
                image: "http://placehold.it/117x71",
                description: "Bivariate analysis - scatter plot"

            }]

        }],
    pretty: true
};