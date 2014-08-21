var AMOUNT = 50;

$("svg rect").on("mouseenter", function() {
    changeColor(this, AMOUNT);
})
$("svg rect").on("mouseleave", function() {
    changeColor(this, -AMOUNT);
})

function changeColor(element, amount) {
   var string = element.getAttribute("fill").split("(")[1];
   string = string.substr(0, string.length-1);
   colors = string.split(",");
   for(var i=0; i<3; i++) {
      colors[i]=parseInt(colors[i])+amount;
   }
   var output = "rgb(" + colors[0] + "," + colors[1] + "," + colors[2] + ")";
   element.setAttribute("fill", output);
}
