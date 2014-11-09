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

    # TODO: handle activation of group/entity
    @tree.on('activate_node.jstree', (e, node) =>
      @loadParamToEditor(@getModelParamById(node.node.id))
      $('#param-config').show()
    )

    # TODO: will be empty on start
    @input_model = [
      {
      "entities": [
          {
            "parameters": [
                {
                  "id": 'param1',
                  'label': 'First',
                  'type': 'float',
                  'min': 0, 'max': 1000
                },
                {
                  "id": 'param2',
                  'label': 'second',
                  'type': 'float',
                  'min': -100, 'max': 100
                },
            ]
          }
        ]
      }
    ]

    @updateTree()
    @tree.show()

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
    $('#param-config #param_id').val(p.id)
    $('#param-config #param_label').val(p.label)
    $('#param-config #param_type').val(p.type)
    $('#param_type').change()


  simpleModelToTreeData: =>
    try
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
      text: p.label,
      type: 'parameter'
    }

  getModelParamById: (id) =>
    @input_model[0].entities[0].parameters.filter((p) -> p.id == id)[0]

  # modify model
  # - edit parameter property -> find parameter in model and modify
  simpleModifyParameter: (param_id, attr, value) =>
    for p in @input_model[0].entities[0].parameters
      if p.id == param_id
        p[attr] = value
        break

  updateTree: =>
    @tree.jstree(
      {
        core: {
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

