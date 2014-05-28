class window.CloudImagesSelector
  constructor: () ->
    @cloudSelect = $("#cloud-select select")
    if @cloudSelect.length <= 0 or (@cloudSelect.length == 1 and @cloudSelect[0].length == 0)
      $("##{@addImageFormId} form :input").prop('disabled', true)
    @cloudSelect.change(@cloudChanged)
    @cloudChanged()

  cloudChanged: =>
    $('div[id^="image-id-row-"]').hide()
    $('div[id^="image-id-row-"] select').prop('disabled', true)
    $('div[id^="image-id-row-"] input').prop('disabled', true)

    cloudName = @cloudSelect.val()
    $("#image-id-row-#{cloudName}").show()
    $("#image-id-row-#{cloudName} select").prop('disabled', false)
    $("#image-id-row-#{cloudName} input").prop('disabled', false)


