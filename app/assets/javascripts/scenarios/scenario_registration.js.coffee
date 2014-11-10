class window.ScenarioRegistration

  constructor: ->
    # bind input designer switch events
    @inputDesignerOnDiv = $("#input-designer-on")
    @inputDesignerOffDiv = $("#input-designer-off")
    @inputDesignerOnDiv.on("click", @inputDesignerOn)
    @inputDesignerOffDiv.on("click", @inputDesignerOff)
    @inputDesignerOnDiv.click()

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

    $('#unsaved-ok').click(-> $('#unsaved-modal').foundation('reveal', 'close'))

    @monitorEditorControls()

    @createSimpleModel()
#    [
#      {
#        "entities": [
#          {
#            "parameters": [
#              {
#                "id": 'param1',
#                'label': 'First',
#                'type': 'float',
#                'min': 0, 'max': 1000
#              },
#                {
#                  "id": 'param2',
#                  'label': 'second',
#                  'type': 'float',
#                  'min': -100, 'max': 100
#                },
#            ]
#          }
#        ]
#      }
#    ]

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
    param_id = $('#param-config #param_id').val()
    param_label = $('#param-config #param_label').val()
    param_type = $('#param-config #param_type').val()

    # getting parameter by old parameter id
    parameter = @getModelParamById(@selectedNodeId)

    parameter.id = param_id
    parameter.label = param_label
    parameter.type = param_type

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
        themes : { stripes : true },
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

    $("#input-definition #input-designer").show()
    $("#input-definition #input-upload").hide()

  inputDesignerOff: (event) =>
    @inputDesignerOnDiv.removeClass("clicked")
    @inputDesignerOffDiv.addClass("clicked")

    $("#input-definition #input-designer").hide()
    $("#input-definition #input-upload").show()

