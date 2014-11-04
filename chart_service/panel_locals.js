module.exports = {
    groups: [
        {
            id: "nasze_2",
            name: "Nasze 2",
            methods: [{
                name: "Interaction",
                id: "interactionModal",
                image: "/chart/images/material_design/interaction_icon.png",
                description: "Shows interaction between 2 input parameters"
            },{
                name: "Pareto",
                id: "paretoModal",
                image: "/chart/images/material_design/pareto_icon.png",
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
                image: "/chart/images/material_design/histogram_icon.png",
                description: "TODO"

            },{
                name: "Regression trees",
                id: "experiment-analysis-modal",
                em_class: "rtree-analysis",
                image: "/chart/images/material_design/regression_icon.png",
                description: "TODO"

            },{
                name: "Scatter plots",
                id: "experiment-analysis-modal",
                em_class: "bivariate-analysis",
                image: "/chart/images/material_design/scatter_icon.png",
                description: "Bivariate analysis - scatter plot"

            }]

        }],
    pretty: true
};