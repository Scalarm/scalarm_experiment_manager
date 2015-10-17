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
    @allowed_infrastructures

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
    
    limit = $('#param-config #limit').val()
    parameter.limit = limit
    parameter.name += "saved"

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
#    @simpleValidation()
    @activateNodeById(@selectedNodeId) if @selectedNodeId

  handleRemoveParam: =>
    @setSaved()
#    @removingValidation()
    @simpleRemoveParam()

  createSimpleModel: =>
    @allowed_infrastructures = [] unless @allowed_infrastructures

#  simpleValidation: =>
#    $('#param-config #param_id').attr('required','required')

#  removingValidation: =>
#    $('#param-config #param_id').removeAttr('required')

  simpleAddParam: =>
    # TODO load infrastructures form?
    @global_param_n = 0 unless @global_param_n
    param_num = @global_param_n++

    @createSimpleModel() # just in case TODO
    @allowed_infrastructures.push({
      id: ('param-' + param_num),
      name: ('Dummy infrastructure'),
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
    if p
      $('#param-config #limit').val(p.limit)
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
    label = @cutText(p.name, 20)
    {
      id: p.id,
      text: "<strong>#{label}</strong>",
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

  cutText: (text, maxChars) ->
    if text.length > maxChars
      "#{text.substring(0, maxChars)}..."
    else
      text

