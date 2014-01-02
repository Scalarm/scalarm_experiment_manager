/**
 * Created with JetBrains RubyMine.
 * User: dkrol
 * Date: 6/5/13
 * Time: 1:37 PM
 * To change this template use File | Settings | File Templates.
 */

function DoeManager() {
    this.doe_groups = [];
    this.range_parameters = [];
    this.next_id = 0;

    this.createDoeGroup = createDoeGroup;
    function createDoeGroup(select_id) {
        var select = $('#' + select_id);

        var doe_label = select.find("option[value='" + select.val() + "']").html();
        var doe_id = select.val();

        var group = $('#doe-group-template').clone();

        group.find('li.title').html(doe_label);
        group.attr('id', 'doe-group-' + this.next_id);
        group.attr('doe-id', doe_id);

        $("div.content[data-slug='doe']").append(group);
        this.putParams('doe-group-' + this.next_id);
        group.show();

        this.next_id += 1;
    }

    this.newRangeParamHandler = newRangeParamHandler;
    function newRangeParamHandler(event) {
        var parameter_id = event.detail.group_id + "___" + event.detail.entity_id + "___" + event.detail.parameter_id;
        doe_manager.range_parameters.push(parameter_id);
        // updating all select elements with parameters
        doe_manager.updateAllSelectElements();
    }

    this.newOtherParamHandler = newOtherParamHandler;
    function newOtherParamHandler(event) {
        var parameter_id = event.detail.entity_id + "___" + event.detail.group_id + "___" + event.detail.parameter_id;
        // remove already parameter if already chosen
        $("[id^='doe-group-'] li.bullet-item").each(function (index, bulletItem) {
            if ($(this).is("[param_id]") && ($(this).attr('param_id') == parameter_id)) {
                $(this).find("a.button").click();
            }
        });
        // remove the parameter from the parameter list
        var index = $.inArray(parameter_id, doe_manager.range_parameters);
        if (index >= 0) {
            doe_manager.range_parameters.splice(index, 1);
        }
        // updating all select elements with parameters
        doe_manager.updateAllSelectElements();
    }

    document.addEventListener("newRangeParameter", this.newRangeParamHandler, false);
    document.addEventListener("newOtherParameter", this.newOtherParamHandler, false);

    this.putParams = putParams;
    function putParams(paramGroupId) {
        var selectElement = $('#' + paramGroupId + " select#parameters");
        selectElement.html('');

        $.each(this.range_parameters, function(index, value) {
          var option = $("<option value='" + value + "'>" + value + "</option>")
          selectElement.append(option);
        });
        // disable button if there is no options
        if(selectElement.html() == '') {
            $('#' + paramGroupId + " select#parameters").hide();
            $('#' + paramGroupId + " .price a.button").hide();
        }
        else { // enable otherwise
            $('#' + paramGroupId + " select#parameters").show();
            $('#' + paramGroupId + " .price a.button").show();
        }
    }

    this.addParameterInGroup = addParameterInGroup;
    function addParameterInGroup(groupElement) {
        var select = groupElement.find('select#parameters');
        var param_label = select.find("option[value='" + select.val() + "']").html();
        var param_id = select.val();

        var me = this;
        // button removing this parameter from its group
        var deleteButton = $("<a href='#'></a>").addClass("button").on('click', function() {
            //get parameter id to remove
            var parameter_id = $(this).closest('li').attr('param_id');
            // add param id to the range parameter list
            me.range_parameters.push(parameter_id);
            // update other select element
            me.updateAllSelectElements();
            // remove the row describing parameter
            $(this).closest('li').remove();
            // prevent from reloading
            return false;
        }).html("Remove");
        // parameter label
        var content = $("<label></label>").html(param_label);
        // row describing the parameter
        var paramElement = $("<li></li>").addClass('bullet-item').attr('param_id', param_id).append(content).append(deleteButton)

        // append this parameter row
        groupElement.find('li.price').after(paramElement)
        // remove parameter id from range parameter list
        var index = $.inArray(param_id, this.range_parameters);
        if (index >= 0) {
            this.range_parameters.splice(index, 1);
        }
        // update select elements
        this.updateAllSelectElements();
    }

    this.updateAllSelectElements = updateAllSelectElements;
    function updateAllSelectElements() {
        $("[id^='doe-group-']").each(function (index, doeGroup) {
            if(this instanceof DoeManager) {
                this.putParams($(doeGroup).attr('id'));
            } else {
                doe_manager.putParams($(doeGroup).attr('id'));
            }
        });
    }

    this.deleteGroup = deleteGroup;
    function deleteGroup(groupElement) {
        groupElement.find(".bullet-item a.button").click();
        groupElement.remove();
    }

    this.updateDoeForSubmit = updateDoeForSubmit;
    function updateDoeForSubmit() {
        var doeTab = [];
//        console.log("Size: " + $("[id^='doe-group-']").length);

        $("[id^='doe-group-']").each(function (index, doeGroup) {
            var doeId = $(doeGroup).attr('doe-id');
//            console.log("Doe id: " + doeId);
            if(doeId != undefined) {
                var parameters = [];

    //            console.log("Parameter list size: " + $(doeGroup).find('li.bullet-item').length);
                $(doeGroup).find('li.bullet-item').each(function(i, parameterBullet) {
    //                console.log("Parameter: " + $(parameterBullet).attr('param_id'));
                    parameters.push($(parameterBullet).attr('param_id'));
                });

                doeTab.push([ doeId, parameters ]);
            }
        });
//        console.log("Stringified doe: " + JSON.stringify(doeTab));
        $("input[name='doe']").val(JSON.stringify(doeTab));
        $("#doe").val(JSON.stringify(doeTab));
    }

    this.checkExperimentSize = checkExperimentSize;
    function checkExperimentSize() {
        updateAllInputParameterValues();
        doe_manager.updateDoeForSubmit();
        $.ajax({
            type: "POST",
            url: $('#calculate-experiment-size-url').val(),
            data: "simulation_id=" + $('#simulation_id').val() + "&experiment_input=" + $('#experiment_input').val() + "&doe=" + $('#doe').val() + "&run_index=" + $('#run_index').val(),
            success: function(msg) {
                $("#experiment-size-dialog #calculated-experiment-size").html(msg.experiment_size);
                $('#experiment-size-dialog').foundation('reveal', 'open');
            }
        });

        return false;
    }

    $("body").delegate("#experiment_submit_form", "submit", this.updateDoeForSubmit);
    $("body").delegate("button#check-experiment-size", "click", this.checkExperimentSize);
}