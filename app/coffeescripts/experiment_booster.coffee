
class window.ExperimentBooster
  constructor: (@dialog_element_id) ->
    @dialogElement = $("#" + @dialog_element_id)
    @accordion_element_id = 'booster_tabs'
    @accordionElement = $('#booster_tabs')
    @loading_id = 'loading-img'
    @loadingElement = $('#loading-img')
    
  initDialog: ->
    $("##{@dialog_element_id}").dialog({ autoOpen: false, height: 'auto', width: 550, modal: true, resizable: true })
    $("##{@accordion_element_id}").accordion( { autoHeight: false } )
    $("##{@dialog_element_id}").css('overflow', 'hidden')
    @loadInfrastructureInfo()
    
  openDialog: ->
    $("##{@dialog_element_id}").dialog('open')
    @loadInfrastructureInfo()
    
  afterSubmit: () ->
    $("##{@dialog_element_id}").dialog('close') 
    $("##{@loading_id}").show()
    
  onSuccess: (msg) ->
    $("##{@loading_id}").hide()
    alert(msg)
    
  loadInfrastructureInfo: ->
    boosterDialog = this
    $.ajax({
      url: "/infrastructure/infrastructure_info",
      success: (resp_data) ->
        resp = JSON.parse(resp_data)
        $('#private_info').text(resp.private)
        $('#plgrid_info').text(resp.plgrid)
        $('#amazon_info').text(resp.amazon)
    })
  