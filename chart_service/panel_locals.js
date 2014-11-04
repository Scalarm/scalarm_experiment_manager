module.exports = {
    groups: [
        {
            id: "group",
            name: "Analyses methods",
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
            },{
                name: "Histograms",
                id: "experiment-analysis-modal",
                em_class: "histogram-analysis",
                image: "/chart/images/material_design/histogram_icon.png",
                description: "Histograms analysis"
            },{
                name: "Regression trees",
                id: "experiment-analysis-modal",
                em_class: "rtree-analysis",
                image: "/chart/images/material_design/regression_icon.png",
                description: "Regression trees analysis"
            },{
                name: "Scatter plots",
                id: "experiment-analysis-modal",
                em_class: "bivariate-analysis",
                image: "/chart/images/material_design/scatter_icon.png",
                description: "Bivariate analysis - scatter plot"
            }]

        }
    ],
    pretty: true
};

//module.exports =
//{
//    groups: [
//                {
//                    id: "<<id_of_group>>",
//                    name: "<<name_of_group>>",
//                    methods: [
//                                {
//                                    id: "<<id_of_method>>",
//                                    name: "<<name_of_method>>",
//                                    image: "<<link_to_image_through_LB>>", //e.g /chart/images/material_design/interaction_icon.png",
//                                    em_class: "{histogram-analysis,rtree-analysis,bivariate-analysis}", //optional!
//                                    description: "<<description>>" //show as tooltip on UI
//                                },
//                                {
//                                    //next method...
//                                }
//                             ]
//                },
//                {
//                    //next group...
//                }
//            ]
//};