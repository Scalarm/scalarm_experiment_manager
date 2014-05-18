/**
 * Created with JetBrains RubyMine.
 * User: dkrol
 * Date: 2/13/13
 * Time: 9:36 PM
 * To change this template use File | Settings | File Templates.
 */

//function parametrizationTypeListener(parameterIndex, groupId, entityId, parameterId) {
//    $("select#parametrization_type_" + parameterIndex).change(function() {
//        buildParameterValuesPartial(parameterIndex, groupId, entityId, parameterId);
//
//        var selectedType = $("select#parametrization_type_" + parameterIndex).val();
//        updateParametrizationTypeInJSON(groupId, entityId, parameterId, selectedType);
//
//        if(selectedType == "range") {
//            document.dispatchEvent(createNewRangeParameter(entityId, groupId, parameterId));
//        } else {
//            document.dispatchEvent(createNewOtherParameter(entityId, groupId, parameterId));
//        }
//
//    });
//}

// DK: generic function for building DOM structure for input parameter
function buildParameterValuesPartial(parameterIndex, groupId, entityId, parameterId) {
//    alert("build - " + parameterIndex);
    var selectElement = $("select#parametrization_type_" + parameterIndex);
    var parameter = $.parseJSON(selectElement.attr("parameter"));

    if(parameter.type == "integer") {
        parameterValuesPartialForInteger(parameter, selectElement.val(), parameterIndex);
    }
    else if(parameter.type == "float") {
        parameterValuesPartialForFloat(parameter, selectElement.val(), parameterIndex);
    }
    else if(parameter.type == "string") {
        parameterValuesPartialForString(parameter, selectElement.val(), parameterIndex);
    }

    $("#parameter_values_" + parameterIndex + " input").bind("change paste keyup", function() {
        var groupId = $(this).parents("div[group_id]").attr("group_id");
        var entityId = $(this).parents("div[entity_id]").attr("entity_id");
        var parameterId = $(this).parents("div[parameter_id]").attr("parameter_id");

//        alert(groupId);
//        alert("ID: " + $(this).attr("id") + " - Val: " + $(this).val());
        var parameterElementId = $(this).attr("id");
        var setValue = $(this).val();
//        alert(parameterElementId + " --- " + setValue);

        $.each(experimentInput, function(index, group) {
            if(group.id == groupId) {
                $.each(group.entities, function(index, entity) {
                    if(entity.id == entityId) {
                        $.each(entity.parameters, function(index, parameter) {
                            if(parameter.id == parameterId) {
                                updateParameterValuesInJSON(parameter, parameterElementId, setValue);
                            }
                        });
                    }
                });
            }
        });
    });
}

//// DK: generates DOM structure for parameter values specifications according to parametrization type
function parameterValuesPartialForInteger(parameter, parametrizationType, parameterId) {
    var container = $("#parameter_values_" + parameterId);
    container.html($("<h4></h4>").addClass('subheader').html("Parameter '" + parameter.label + "' with ID: " + parameter.id +
        " - [ " + parameter.min + ", " + parameter.max + " ]"));

    if (parametrizationType == "value") {
        var default_value = (parameter.value != undefined) ? parameter.value : parameter.min;
        container.append(labeledInput("Set value: ", "parameter_value_" + parameterId, default_value));
    }
    else if (parametrizationType == "range") {
        container.append(labeledInput("Set min: ", "parameter_min_" + parameterId, parameter.min))
            .append(labeledInput("Set max: ", "parameter_max_" + parameterId, parameter.max))
            .append(labeledInput("Set step: ", "parameter_step_" + parameterId, (parameter.min + parameter.max) / 5.0));
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
    container.html($("<h4></h4>").addClass('subheader').html("Parameter '" + parameter.label + "' with ID: " + parameter.id +
        " - [ " + parameter.min + ", " + parameter.max + " ]" ));

    if(parametrizationType == "value") {
        var default_value = (parameter.value != undefined) ? parameter.value : parameter.min;
        container.append(labeledInput("Set value: ", "parameter_value_" + parameterId, default_value));
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

    container.html($("<h4></h4>").addClass('subheader').html(containerHeader));
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
    var inputTemplate = $("<input type='text' />")
    var labelElement = $("<label></label>").addClass('inline').addClass('right').html(label);

    var labeledInput = $("<div></div>").addClass('row').
        append($("<div></div>").addClass('small-5').addClass('columns').append(labelElement)).
        append($("<div></div>").addClass('small-7').addClass('columns').append(
        inputTemplate.clone().attr("id", elementId).val(defaultValue))
    );

    return labeledInput;
}

// updates experiment input model stored in global 'experimentInput' variable as JSON
//function updateParametrizationTypeInJSON(groupId, entityId, parameterId, selectedType) {
////    alert("Updating parametrization of - " + groupId + " (" + entityId + ") - to " + selectedType);
////    alert(experimentInput);
//    $.each(experimentInput, function(index, group) {
//        if(group.id == groupId) {
//            $.each(group.entities, function(index, entity) {
//                if(entity.id == entityId) {
//                    $.each(entity.parameters, function(index, parameter) {
//                        if(parameter.id == parameterId) {
////                            alert("Old value: " + parameter["parametrizationType"] + " - New value: " + selectedType);
//                            parameter["parametrizationType"] = selectedType;
//                        }
//                    });
//                }
//            });
//        }
//    });
//}

// updates experiment input model stored in global 'experimentInput' variable as JSON
function updateParameterValuesInJSON(parameter, parameterElementId, setValue) {
    if(parameter.parametrizationType == "value") {
        if(parameter.type == "string") {
            var setValue = parameterElementId.substring(0, parameterElementId.lastIndexOf("_"));
            parameter["value"] = setValue;
        }
        else {
            parameter["value"] = $("#" + parameterElementId).val();
        }
    }
    else if(parameter.parametrizationType == "gauss") {
        if(parameterElementId.indexOf("mean") >= 0) {
            parameter["mean"] = setValue;
        }
        else if(parameterElementId.indexOf("variance") >= 0) {
            parameter["variance"] = setValue;
        }
    }
    else if(parameter.parametrizationType == "uniform") {
        if (parameterElementId.indexOf("min") >= 0) {
            parameter["min"] = setValue;
        }
        else if (parameterElementId.indexOf("max") >= 0) {
            parameter["max"] = setValue;
        }
    }
    else if(parameter.parametrizationType == "range") {
        if (parameterElementId.indexOf("min") >= 0) {
            parameter["min"] = setValue;
        }
        else if (parameterElementId.indexOf("max") >= 0) {
            parameter["max"] = setValue;
        }
        else if (parameterElementId.indexOf("step") >= 0) {
            parameter["step"] = setValue;
        }
    }
    else if(parameter.parametrizationType == "multiple") {
        setValue = parameterElementId.substring(0, parameterElementId.lastIndexOf("_"));

        if(parameter["value"] == undefined || parameter["value"] == null) {
            parameter["value"] = [ setValue ];
        }
        else {
            var elementIndex = $.inArray(setValue, parameter["value"]);
            if(elementIndex >= 0) {
                parameter["value"].splice(elementIndex, 1);
            }
            else {
                parameter["value"].push(setValue);
            }
        }
    }
}

function updateAllInputParameterValues() {
    $("div[id^='parameter_values_'] input").each(function (index, element) {
        var groupId = $(element).parents("div[group_id]").attr("group_id");
        var entityId = $(element).parents("div[entity_id]").attr("entity_id");
        var parameterId = $(element).parents("div[parameter_id]").attr("parameter_id");

        var parameterElementId = $(element).attr("id");
        var setValue = $(element).val();

        $.each(experimentInput, function (index, group) {
            if (group.id == groupId) {
                $.each(group.entities, function (index, entity) {
                    if (entity.id == entityId) {
                        $.each(entity.parameters, function (index, parameter) {
                            if (parameter.id == parameterId) {
                                var parameterIndex = parameterElementId.substring(parameterElementId.lastIndexOf("_") + 1);
                                parameter["parametrizationType"] = $("#parametrization_type_" + parameterIndex).val();
                                updateParameterValuesInJSON(parameter, parameterElementId, setValue);
                            }
                        });
                    }
                });
            }
        });
    });

    $("input[name='experiment_input']").val(JSON.stringify(experimentInput));
}

//function createNewRangeParameter(entity_id, group_id, parameter_id) {
//    return new CustomEvent(
//        "newRangeParameter",
//        {
//            detail: {
//                entity_id: entity_id,
//                group_id: group_id,
//                parameter_id: parameter_id
//            },
//            bubbles: true,
//            cancelable: true
//        });
//}
//
//function createNewOtherParameter(entity_id, group_id, parameter_id) {
//    return new CustomEvent(
//        "newOtherParameter",
//        {
//            detail: {
//                entity_id: entity_id,
//                group_id: group_id,
//                parameter_id: parameter_id
//            },
//            bubbles: true,
//            cancelable: true
//        });
//}
