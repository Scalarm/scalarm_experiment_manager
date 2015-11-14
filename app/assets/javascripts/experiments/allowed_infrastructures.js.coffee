class window.AllowedInfrastructures

  constructor: () ->
    @allowed_infrastructures_form = $('#allowed_infrastructures')

    # TODO make themes support
    #$.jstree._themes = '/assets/jstree-themes/'

    @tree = $("#params-tree")

    $('#add-param').click(@handleAddParam)
    $('#remove-param').click(@handleRemoveParam)

    $('#editor-save').click(=>ignore_if_disabled($('#editor-save'), @saveParameterChanges))
    $('#editor-discard').click(=> ignore_if_disabled($('#editor-discard'), @discardParameterChanges))

    $('#unsaved-ok').click(->
      $('#unsaved-modal').foundation('reveal', 'close')
      $('html, body').animate({
        scrollTop: $("#input-designer").offset().top
      }, 2000);
    )
    $('#invalid-modal-ok').click(->
      $('#invalid-modal').foundation('reveal', 'close')
      $('html, body').animate({
        scrollTop: $("#input-designer").offset().top
      }, 2000);
    )

    @editorSaveOnEnter($("#limit"))

    @monitorEditorControls()
    @createSimpleModel()

    @editorModified = false
    @updateTree()
    @tree.show()

  editorSaveOnEnter: (object) =>
    object.keypress((event) =>
      if event.keyCode == 13
        $("#editor-save").click()
        false
      else
        true
    )

  getAllowedInfrastructures: =>
    @allowed_infrastructures.filter (entry) ->
        entry.name != ""
      .map (entry) ->
        {
          name: entry.name,
          params: entry.params
          limit: entry.limit
        }

  monitorEditorControls: =>
    $('#param-config input').on('input', => @setModified())
    $('#param-config select').on('change', => @setModified())
    $('#param-config textarea').on('input', => @setModified())
    $('#param-config input:checkbox').on('change', => @setModified())

  setModified: =>
    @editorModified = true
    $('#editor-save').removeClass('disabled')
    $('#editor-discard').removeClass('disabled')

  setSaved: =>
    @editorModified = false
    $('#editor-save').addClass('disabled')
    $('#editor-discard').addClass('disabled')


  saveParameterChanges: =>
    if $("#param-config").find(':input[data-invalid]:visible').length==0
      @saveEditorToParam()
      @setSaved()
    else
      $("#param-config").find('[data-invalid]').blur()
      $('#invalid-modal').foundation('reveal', 'open')

  discardParameterChanges: =>
    @activateParam(@selectedNodeId)
    @setSaved()

  saveEditorToParam: () =>
    # getting parameter by old parameter id
    parameter = @getModelParamById(@selectedNodeId)

    parameter.limit = Number($('#param-config #limit').val())
    params = {}
    for key in $('#param-config *').filter(':input')
      if key.id != 'infrastructure_name' and key.id != 'limit'
        params[key.id] = key.value
    parameter.name = $('#param-config #infrastructure_name').val()
    parameter.label = $('#param-config #infrastructure_name option:selected').text()
    parameter.params = params

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
    @setSaved()
    @simpleRemoveParam()

  createSimpleModel: =>
    @allowed_infrastructures = [] unless @allowed_infrastructures

  simpleAddParam: =>
    @global_param_n = 0 unless @global_param_n
    param_num = @global_param_n++

    @createSimpleModel()
    @allowed_infrastructures.push({
      id: ('param-' + param_num),
      name: '',
      label: 'Unset',
      params: {}
      limit: 0
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
      @allowed_infrastructures.splice(index, 1)
      @updateTree()
      @loadParamToEditor(null)


  loadParamToEditor: (p) =>
    @monitorEditorControls()
    if p
      if p.name != ""
        $('#param-config #infrastructure_name').val(p.name)
      else
        $('#param-config #infrastructure_name').val('private_machine')
      window.infrastructures_booster.onInfrastructuresSelectChange()
      $('#param-config #limit').val(p.limit)
      for key of p.params
        $('#param-config #' + key).val(p.params[key])
      $('#param-config').show()
    else
      $('#param-config').hide()


  simpleModelToTreeData: =>
    try
      return [] unless @allowed_infrastructures
      parameters = @allowed_infrastructures
      parameters.map(@paramModelToTree)
    catch error
      console.log error
      [
        'An error occured!'
      ]

  paramModelToTree: (p) =>
    {
      id: p.id,
      text: "<strong>#{p.label} (#{p.limit})</strong>",
      type: 'parameter'
    }

  getModelParamById: (id) =>
    @allowed_infrastructures.filter((p) -> p.id == id)[0]

  getModelParamIndexById: (id) =>
    parameters = @allowed_infrastructures
    for i in [0..parameters.length-1] by 1
      return i if parameters[i].id == id

  # modify model
  # - edit parameter property -> find parameter in model and modify
  simpleModifyParameter: (param_id, attr, value) =>
    for p in @allowed_infrastructures
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
            icon : "fa fa-cogs"
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

