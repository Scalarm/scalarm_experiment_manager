
class window.PrivateInfrastructureFacet
  constructor: ->

  label: () ->
    label = $('<div>').append($('<div>').text("Private Infrastructure"))
              .append(@imageButton("run"))
              .append(@imageButton("stop"))
              .append(@imageButton("add-icon"))

    $('<div>').append(label)

  imageButton: (icon_name) ->
    onclick = if icon_name == "add-icon"
      "$('#register_simulation_manager_form').dialog('open')"
    else
      "window.SimulationManagerFacet.call_on_all('#{icon_name}')"

    "<img src='/images/#{icon_name}.png' onclick=#{onclick} />"


class window.SimulationManagerFacet
  constructor: (@obj_id, @object_state = null) ->
    @object_state = JSON.parse(@object_state) if @object_state != null
    @busy_icon_id = "busy_sm_#{@obj_id}"

  manage_remote_object: (method_name) ->
    facet = new window.SimulationManagerFacet(@obj_id)
    $("##{facet.busy_icon_id}").show()

    $.post('/infrastructure/manage_simulation_manager_host',
      { simulation_manager_host_id: @obj_id, method: method_name },
    facet.update_html)

  update_html: (new_object_state) ->
    object_state = JSON.parse(new_object_state)
    smf = new SimulationManagerFacet(object_state.obj_id, new_object_state)
    smf.update_dom_element()

  update_dom_element: ->
    if @object_state.state == "destroyed"
      $("#sm-#{@obj_id}").html(@to_html().html())
    else
      infrastructure_tree.removeSubtree("sm-#{@obj_id}", true, 'replot', { } )

  busy_icon: ->
    if($("##{@busy_icon_id}") != null)
      return $("##{@busy_icon_id}")
    else
      return

  to_html: ->
    server_icon = $('<img>').attr('src', '/images/server-icon.png')
    state_span = $('<span>').addClass('state').text(@object_state.state)

    $('<div>').append(server_icon).append("#{@object_state.ip} State: ").append(state_span).append(@buttons(@object_state.state))

  @call_on_all: (method_name) ->
    $('[id^="sm-"]').each((i, element) ->
      element_id = $(element).attr('id').split("sm-")[1];
      new SimulationManagerFacet(element_id).manage_remote_object(method_name)
    )

  @create_json_obj: (id, state) ->
     'id': "sm-#{id}", 'name': new SimulationManagerFacet(id, state).to_html().html(), 'children': [ ], 'data' : {}


#    ========= PRIVATE ===========

  buttons: (state) ->
    buttons_list = null

    if(state == "running")
      buttons_list = $('<div>').append(@imageButton(@obj_id, "run", false)).append(@imageButton(@obj_id, "stop"))
    else
      buttons_list = $('<div>').append(@imageButton(@obj_id, "run")).append(@imageButton(@obj_id, "stop", false))

    busy_icon = $('<img>').attr({ src: '/images/loading.gif', id: @busy_icon_id, width: 16 })
    buttons_list.append(@imageButton(@obj_id, "unregister")).append(busy_icon.hide())


  imageButton: (obj_id, name, enabled = true) ->
    if(enabled)
      "<img src=\"/images/#{name}.png\" alt=\"private_#{name}\" onclick=\"new window.SimulationManagerFacet('#{obj_id}').manage_remote_object('#{name}');\" >"
    else
      $('<img>').attr('src', "/images/#{name}_gray.png").attr('alt', "private_#{name}")
