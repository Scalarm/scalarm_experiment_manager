class window.ParameterConstraintsManager
  constructor: () ->
    @rangeParameters = []
    document.addEventListener("parametrizationTypeChange", @parametrizationTypeChangeListener, false)

    $("#addConstraint").on "click", () =>
      sourceParameter = $(".constraint-specs #source-parameter :selected")
      targetParameter = $(".constraint-specs #target-parameter :selected")

      $("#constraints-list").append($("#constraintTemplate").tmpl([
        sourceParameter:
          uid: sourceParameter.val()
          label: sourceParameter.text()
        targetParameter:
          uid: targetParameter.val()
          label: targetParameter.text()
        condition: $(".constraint-specs #condition :selected").val()
      ]))

      $("#constraints-list .button").on "click", () -> $(this).closest(".row").remove()

    $("#check-experiment-size").on "click", () =>
      @getParametersConstraints()


  getParametersConstraints: () =>
    constraints = []
    $.each $("#constraints-list .row"), (index, rowElement) =>
      constraints.push(
        source_parameter: $(rowElement).find("[source-parameter-uid]").attr("source-parameter-uid")
        target_parameter: $(rowElement).find("[target-parameter-uid]").attr("target-parameter-uid")
        condition: $(rowElement).find("[condition]").attr("condition")
      )
    $("#parameters_constraints").val(JSON.stringify(constraints))



  parametrizationTypeChangeListener: (event) =>
    parameterId = [event.detail.entityGroupId, event.detail.entityId, event.detail.parameterId].filter(
      (n) ->
        n != undefined && n != ""
    ).join("___")

    parameter = InputSpace.getParameter(event.detail.entityGroupId, event.detail.entityId, event.detail.parameterId)

    if (event.detail.parametrizationType == "range" || event.detail.parametrizationType == "custom") &&
    (parameter.parameter.type == "integer" || parameter.parameter.type == "float")
      if not @isRangeParameterAdded(event.detail.entityGroupId, event.detail.entityId, event.detail.parameterId)
        @addRangeParameter(event.detail.entityGroupId, event.detail.entityId, event.detail.parameterId)

    else
#    remove already parameter if already chosen
#      $("[id^='doe-group-'] li.bullet-item").each (index, bulletItem) =>
#        if $(bulletItem).is("[param_id]") and ($(bulletItem).attr('param_id') == parameterId)
#          $(bulletItem).find("a.button").click()
  #    remove the parameter from the parameter list
        @removeRangeParameter(parameterId)

    @updateSelectElements()

  # add a parameter to the internal range parameter list
  addRangeParameter: (entityGroupId, entityId, parameterId) =>
    if entityId == undefined && parameterId == undefined
      fullParameterId = entityGroupId
      id_info = entityGroupId.split('___')

      parameterId = id_info[id_info.length - 1]
      entityId = id_info[id_info.length - 2]
      entityGroupId = id_info[id_info.length - 3]
    else
      fullParameterId = parameterId
      fullParameterId = "#{entityId}___#{fullParameterId}" if entityId != undefined && entityId != ""
      fullParameterId = "#{entityGroupId}___#{fullParameterId}" if entityGroupId != undefined && entityGroupId != ""

    parameter = InputSpace.getParameter(entityGroupId, entityId, parameterId)

    @rangeParameters.push
      fullId: fullParameterId
      entityGroup: parameter.entityGroup
      entity: parameter.entity
      parameter: parameter.parameter

  # remove the parameter from the internal range parameter list
  removeRangeParameter: (fullParameterId) =>
    index = -1
    for parameter, i in @rangeParameters
      if parameter.fullId == fullParameterId
        index = i
    @rangeParameters.splice(index, 1) if index >= 0

  # updating all select elements with parameters
  updateSelectElements: () =>
    sourceParametersElement = $(".constraint-specs #source-parameter").html('')
    targetParametersElement = $(".constraint-specs #target-parameter").html('')

    for p in @rangeParameters
      parameterLabel = ""
      parameterLabel += p.entityGroup['label'] + " - " if p.entityGroup['label'] != undefined
      parameterLabel += p.entity['label'] + " - " if p.entity['label'] != undefined
      parameterLabel += p.parameter['label']

      option = $("<option value='#{p.fullId}'>#{parameterLabel}</option>")
#      option = $("option").val(p.fullId).text(parameterLabel)
      sourceParametersElement.append(option.clone())
      targetParametersElement.append(option.clone())

  isRangeParameterAdded: (entityGroupId, entityId, parameterId) =>
    output = @rangeParameters.filter (rangeParameter) ->
      rangeParameter.parameter == InputSpace.getParameter(entityGroupId, entityId, parameterId).parameter

    return output.length > 0
