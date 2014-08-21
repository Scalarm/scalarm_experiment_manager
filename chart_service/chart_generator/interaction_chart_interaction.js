//variable i is defined in chart_service.js - in anonymous function (to provide local scope for 'i')
function interaction_interaction(i) {
	$("#interaction_chart_" + i + " circle").on("mouseenter", function() {
		console.log("mouseenter " + i);
	});
}
