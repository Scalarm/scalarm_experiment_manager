class window.ScenarioRegistration

  constructor: ->
    # bind input designer switch events
    @inputDesignerOnDiv = $("#input-designer-on")
    @inputDesignerOffDiv = $("#input-designer-off")
    @inputDesignerOnDiv.on("click", @inputDesignerOn)
    @inputDesignerOffDiv.on("click", @inputDesignerOff)
    # use designer by default
    @inputDesignerOnDiv.click()

    @designer_value = $('#designer_value')

    # handle param_type selector events
    $('#param_type').change(@handleParamTypeChanged)

    @parameterSpecificationDiv = $('#params-config')

    # TODO make themes support
    #$.jstree._themes = '/assets/jstree-themes/'

    @tree = $("#params-tree")

    $('#add-param').click(@handleAddParam)
    $('#remove-param').click(@handleRemoveParam)

    $('#editor-save').click(=> ignore_if_disabled($('#editor-save'), @saveParameterChanges))
    $('#editor-discard').click(=> ignore_if_disabled($('#editor-discard'), @discardParameterChanges))

    $('#unsaved-ok').click(->
      $('#unsaved-modal').foundation('reveal', 'close')
      $('html, body').animate({
        scrollTop: $("#input-designer").offset().top
      }, 2000);
    )

    $('#scenario_form').submit(@formSubmit)

    @monitorEditorControls()
    @createSimpleModel()

    @editorModified = false
    @updateTree()
    @tree.show()

  monitorEditorControls: =>
    $('#param-config input').on('input', => @setModified())
    $('#param-config select').on('change', => @setModified())
    $('#param-config textarea').on('input', => @setModified())

  setModified: =>
    @editorModified = true
    $('#editor-save').removeClass('disabled')
    $('#editor-discard').removeClass('disabled')

  setSaved: =>
    @editorModified = false
    $('#editor-save').addClass('disabled')
    $('#editor-discard').addClass('disabled')

  saveParameterChanges: =>
    @saveEditorToParam()
    @setSaved()

  discardParameterChanges: =>
    @activateParam(@selectedNodeId)
    @setSaved()

  saveEditorToParam: () =>
    # getting parameter by old parameter id
    parameter = @getModelParamById(@selectedNodeId)

    param_id = $('#param-config #param_id').val()
    param_label = $('#param-config #param_label').val()
    param_type = $('#param-config #param_type').val()

    parameter.id = param_id
    parameter.label = param_label
    parameter.type = param_type

    if param_type == 'string'
      param_allowed = $('#param-config #param_allowed_area').val()
      allowed = param_allowed.split(/\n|\r\n/)
      parameter.allowed_values = allowed

    else if (param_type == 'integer' || param_type == 'float')
      param_min = $('#param-config #param_min').val()
      parameter.min = (param_type == 'integer' && parseInt(param_min) || parseFloat(param_min))
      param_max = $('#param-config #param_max').val()
      parameter.max = (param_type == 'integer' && parseInt(param_max) || parseFloat(param_max))


    @updateTree()
    @loadParamToEditor(null)
    @setSaved()

  bindActivateNode: =>
    # TODO: handle activation of group/entity
    @tree.on('activate_node.jstree', (e, node) =>
      if @editorModified
        $('#unsaved-modal').foundation('reveal', 'open')
        @activateNodeById(@selectedNodeId)
      else
        @activateParam(node.node.id)
    )

  activateParam: (id) =>
    @selectedNodeId = id
    @loadParamToEditor(@getModelParamById(@selectedNodeId))

  handleAddParam: =>
    @simpleAddParam()
    @activateNodeById(@selectedNodeId) if @selectedNodeId

  handleRemoveParam: =>
    @simpleRemoveParam()

  createEmptyGroup: =>
    {entities: []}

  createEmptyEntity: =>
    {parameters: []}

  createSimpleModel: =>
    @input_model = [] unless @input_model
    @input_model.push(@createEmptyGroup()) unless @input_model[0]
    @input_model[0].entities.push(@createEmptyEntity()) unless @input_model[0].entities[0]

  simpleAddParam: =>
    @global_param_n = 0 unless @global_param_n
    param_num = @global_param_n++

    @createSimpleModel() # just in case TODO
    @input_model[0].entities[0].parameters.push({
      id: ('param-' + param_num),
      label: ('New parameter'),
      type: 'integer',
      min: 0, max: 100
    })
    @updateTree()

  getSelectedNodeId: =>
    @tree.jstree(true).get_selected()[0]

  activateNodeById: (id) =>
    tree_ref = @tree.jstree(true)
    tree_ref.deselect_node(@getSelectedNodeId())
    tree_ref.select_node(id)

  simpleRemoveParam: =>
    param_id = @getSelectedNodeId()
    if param_id
      index = @getModelParamIndexById(param_id)
      @input_model[0].entities[0].parameters.splice(index, 1)
      @updateTree()
      @loadParamToEditor(null)

  handleParamTypeChanged: =>
    type = $('#param_type').val()
    if type == 'string'
      $('#param-allowed').show()
      $('#param-range').hide()
    else if (type == 'integer' || type == 'float')
      $('#param-allowed').hide()
      $('#param-range').show()
    else
      $('#param-allowed').hide()
      $('#param-range').hide()

  loadParamToEditor: (p) =>
    if p
      $('#param-config #param_id').val(p.id)
      $('#param-config #param_label').val(p.label || '')
      $('#param-config #param_type').val(p.type || 'integer')
      $('#param-config #param_min').val(p.min? && p.min.toString() || '')
      $('#param-config #param_max').val(p.max? && p.max.toString() || '')
      $('#param-config #param_allowed_area').val(p.allowed_values && p.allowed_values.join("\n") || '')

      @handleParamTypeChanged()
      $('#param-config').show()
    else
      $('#param-config').hide()


  simpleModelToTreeData: =>
    try
      return [] unless @input_model[0]
      return [] unless @input_model[0].entities[0]
      parameters = @input_model[0].entities[0].parameters
      parameters.map(@paramModelToTree)
    catch error
      console.log error
      [
        'An error occured!'
      ]

  paramModelToTree: (p) =>
    {
      id: p.id,
      text: "<strong>#{p.label}</strong> (#{p.id})",
      type: 'parameter'
    }

  getModelParamById: (id) =>
    @input_model[0].entities[0].parameters.filter((p) -> p.id == id)[0]

  getModelParamIndexById: (id) =>
    parameters = @input_model[0].entities[0].parameters
    for i in [0..parameters.length-1] by 1
      return i if parameters[i].id == id

  # modify model
  # - edit parameter property -> find parameter in model and modify
  simpleModifyParameter: (param_id, attr, value) =>
    for p in @input_model[0].entities[0].parameters
      if p.id == param_id
        p[attr] = value
        break

  updateTree: =>
    @tree.jstree('destroy')
    @tree.jstree({
        core: {
          multiple: false,
          data: @simpleModelToTreeData()
        },
        animation : 0,
        check_callback : true,
        types : {
          parameter : {
            max_children : 0,
            max_depth : 0,
            icon : "fa fa-file-powerpoint-o"
          }
        },
        plugins : [
          #"contextmenu",
          #"dnd",
          #"search",
          #"state",
          "types",
          "wholerow"
        ]
      })
    @bindActivateNode()

    @tree.on('redraw.jstree', => @activateNodeById(@selectedNodeId))


  inputDesignerOn: (event) =>
    @inputDesignerOnDiv.addClass("clicked")
    @inputDesignerOffDiv.removeClass("clicked")

    $("#input-designer").show()
    $("#input-designer #param-config").enable()
    $("#input-upload").hide()
    $("#input-upload #simulation_input_file").disable()

  inputDesignerOff: (event) =>
    @inputDesignerOnDiv.removeClass("clicked")
    @inputDesignerOffDiv.addClass("clicked")

    $("#input-designer").hide()
    $("#input-designer #param-config").disable()
    $("#input-upload").show()
    $("#input-upload #simulation_input_file").enable()

  isDesignerUsed: =>
    @inputDesignerOnDiv.is(".clicked")

  formSubmit: =>
    if @isDesignerUsed()
      if @editorModified
        $('#unsaved-modal').foundation('reveal', 'open')
        false
      else
        # send designer model data
        @designer_value.enable()
        @designer_value.val(JSON.stringify(@input_model))
        true
    else
      @designer_value.disable()
      true

