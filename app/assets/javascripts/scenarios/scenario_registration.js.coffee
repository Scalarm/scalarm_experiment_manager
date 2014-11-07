class window.ScenarioRegistration

  constructor: ->
    $("#input-designer-on").on("click", @inputDesignerOn)
    $("#input-designer-off").on("click", @inputDesignerOff)

    $("#input-designer-on").click()

  inputDesignerOn: (event) ->
    console.log 'hello on'

    $("#input-designer-on").addClass("clicked")
    $("#input-designer-off").removeClass("clicked")

    $("#input-definition #input-designer").show()
    $("#input-definition #input-upload").hide()

  inputDesignerOff: (event) ->
    console.log 'hello off'

    $("#input-designer-on").removeClass("clicked")
    $("#input-designer-off").addClass("clicked")

    $("#input-definition #input-designer").hide()
    $("#input-definition #input-upload").show()

