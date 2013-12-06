// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require foundation
//= require turbolinks
//= require_tree .
//= require highcharts/highcharts
//= require highcharts/highcharts-more
//= require highcharts/modules/exporting
//= require jquery.dataTables.min
//= require jit-yc


$(function(){ $(document).foundation(); });

function string_with_delimeters() {
    var string_copy = this.split("").reverse().join("");
    var len = 3; var num_of_comas = 0;

    while((len + num_of_comas <= string_copy.length) && string_copy.length > 3) {
        string_copy = string_copy.substr(0,len) + "," + string_copy.substr(len);
        num_of_comas = 1; len += 4;
    }

    return string_copy.split("").reverse().join("");
}

String.prototype.with_delimeters = string_with_delimeters;