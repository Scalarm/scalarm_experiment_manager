class window.ScenarioRegistration

  constructor: ->
    $("#input-designer-on").on("click", @inputDesignerOn)
    $("#input-designer-off").on("click", @inputDesignerOff)

    $("#input-designer-on").click()

    $.jstree._themes = '/assets/jstree-themes/'

    @parameters = [
      {
        'text': "Param 1",
        'type': "parameter",
        'data': "hello"
      }
      {
        'text': "Param 2",
        'type': "parameter",
        'data': "hello2"
      }
    ]

    @tree = $("#params-tree")
    @updateTree()
    @tree.show()

  updateTree: ->
    @tree.jstree({
      "core": {
        'data': @parameters
      },
      "animation" : 0,
      "check_callback" : true,
      "themes" : { "stripes" : true },
      "types" : {
        "parameter" : {
          "max_children" : 0,
          "max_depth" : 0,
          "icon" : "fi-asterisk"
        }
      },
      "plugins" : [
        "contextmenu", "dnd", "search",
        "state", "types", "wholerow"
      ]
    })



  inputDesignerOn: (event) ->
    $("#input-designer-on").addClass("clicked")
    $("#input-designer-off").removeClass("clicked")

    $("#input-definition #input-designer").show()
    $("#input-definition #input-upload").hide()

  inputDesignerOff: (event) ->
    $("#input-designer-on").removeClass("clicked")
    $("#input-designer-off").addClass("clicked")

    $("#input-definition #input-designer").hide()
    $("#input-definition #input-upload").show()

