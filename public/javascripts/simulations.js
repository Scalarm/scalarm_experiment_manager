/**
 * Created with JetBrains RubyMine.
 * User: dkrol
 * Date: 2/13/13
 * Time: 9:36 PM
 * To change this template use File | Settings | File Templates.
 */

function parametrizationTypeListener(parameterId) {
    $("select#parametrization_type_" + parameterId).change(function() {
//        var selectedType = $("select#parametrization_type_" + parameterId).val();
        buildParameterValuesPartial(parameterId);
    });
}

// DK: generic function for building DOM structure for input parameter
function buildParameterValuesPartial(parameterId) {
    var selectElement = $("select#parametrization_type_" + parameterId);
    var parameter = $.parseJSON(selectElement.attr("parameter"));

    if(parameter.type == "integer") {
        parameterValuesPartialForInteger(parameter, selectElement.val(), parameterId);
    }
    else if(parameter.type == "float") {
        parameterValuesPartialForInteger(parameter, selectElement.val(), parameterId);
    }
    else if(parameter.type == "string") {
        parameterValuesPartialForString(parameter, selectElement.val(), parameterId);
    }
}

// DK: generates DOM structure for parameter values specifications according to parametrization type
function parameterValuesPartialForInteger(parameter, parametrizationType, parameterId) {
    var container = $("#parameter_values_" + parameterId);
    container.html($("<h4></h4>").html("Parameter '" + parameter.label + "' with ID: " + parameter.id +
        " - [ " + parameter.min + ", " + parameter.max + " ]"));

    if (parametrizationType == "value") {
        container.append(labeledInput("Set value: ", "parameter_value_" + parameterId, parameter.min));
    }
    else if (parametrizationType == "range") {
        container.append(labeledInput("Set min: ", "parameter_min_" + parameterId, parameter.min))
            .append(labeledInput("Set max: ", "parameter_max_" + parameterId, parameter.max))
            .append(labeledInput("Set step: ", "parameter_step_" + parameterId, Math.round((parameter.min + parameter.max) / 5)));
    }
    else if (parametrizationType == "gauss") {
        var mean_value = Math.round((parameter.min + parameter.max) / 2);

        container.append(labeledInput("Set distribution mean value: ", "parameter_mean_" + parameterId, mean_value))
            .append(labeledInput("Set distribution variance value: ", "parameter_variance_" + parameterId, mean_value))
    }
    else if (parametrizationType == "uniform") {
        container.append(labeledInput("Set distribution min value: ", "parameter_min_" + parameterId, parameter.min))
            .append(labeledInput("Set distribution max value: ", "parameter_max_" + parameterId, parameter.max))
    }
}

// DK: generates DOM structure for parameter values specifications according to parametrization type
function parameterValuesPartialForFloat(parameter, parametrizationType, parameterId) {
    var container = $("#parameter_values_" + parameterId);
    container.html($("<h4></h4>").html("Parameter '" + parameter.label + "' with ID: " + parameter.id +
        " - [ " + parameter.min + ", " + parameter.max + " ]" ));

    if(parametrizationType == "value") {
        container.append(labeledInput("Set value: ", "parameter_value_" + parameterId, parameter.min));
    }
    else if(parametrizationType == "range") {
        container.append(labeledInput("Set min: ", "parameter_min_" + parameterId, parameter.min))
            .append(labeledInput("Set max: ", "parameter_max_" + parameterId, parameter.max))
            .append(labeledInput("Set step: ", "parameter_step_" + parameterId, (parameter.min + parameter.max) / 5));
    }
    else if(parametrizationType == "gauss") {
        var mean_value = (parameter.min + parameter.max) / 2;

        container.append(labeledInput("Set distribution mean value: ", "parameter_mean_" + parameterId, mean_value))
            .append(labeledInput("Set distribution variance value: ", "parameter_variance_" + parameterId, mean_value))
    }
    else if(parametrizationType == "uniform") {
        container.append(labeledInput("Set distribution min value: ", "parameter_min_" + parameterId, parameter.min))
            .append(labeledInput("Set distribution max value: ", "parameter_max_" + parameterId, parameter.max))
    }
}

// DK: generates DOM structure for parameter values specifications according to parametrization type
function parameterValuesPartialForString(parameter, parametrizationType, parameterId) {
    var container = $("#parameter_values_" + parameterId);

    var containerHeader = "Parameter '" + parameter.label + "' with ID: " + parameter.id;

    if(parameter.possible_values != undefined) {
        containerHeader += " - possible values: [ " + parameter.possible_values + " ]";
    }

    container.html($("<h4></h4>").html(containerHeader));
//  display checkboxes for possible values
    if(parameter.possible_values != undefined) {
        var buttonSet = $("<div></div>").attr("id", "parameter_value_" + parameterId);

        var typePart = "type='checkbox'";

        if(parametrizationType == "value") {
            typePart = "type='radio' name='radio'";
        }

        $.each(parameter.possible_values, function(index, value) {
            var elementId = value + "_" + parameterId;

            buttonSet.append("<input " + typePart + " id='" + elementId + "' />")
                .append("<label for='" + elementId + "'>" + value + "</label>");
        });

        container.append(buttonSet);
        $(buttonSet).buttonset();
    }
    else {
        container.append(labeledInput("Set value: ", "parameter_value_" + parameterId, ""))
    }
}

// util function for creating <div> with text and input inside
function labeledInput(label, elementId, defaultValue) {
    var inputTemplate = $("<input type='text' />").addClass("nice_input");
    var labelElement = $("<label></label>").html(label);

    var labeledInput = $("<div></div>").append(labelElement).append(
        inputTemplate.clone().attr("id", elementId).val(defaultValue)
    );

    return labeledInput;
}

function updateParametrizationTypeInJSON() {

}

function updateParameterValuesInJSON() {

}
