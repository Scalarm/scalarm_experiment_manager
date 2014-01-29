class window.ImagesManager
  constructor: (@dialogId) ->
    @responsePanel = $('#images_manager-ajax-response')
#    @loading = $('.images_manager-busy')
    @bindToRemoveButton()

#    $('#images_manager-ajax-response').hide()

  bindToRemoveButton: =>
    $(".images form")
    .bind('ajax:before', =>
#        @loading.show()
        @responsePanel.html('')
      )
    .bind('ajax:success', (data, status, xhr) =>
        @responsePanel.html(status.msg).removeClass('alert').addClass('success')
        $("##{status.cloud_name}-#{status.image_id}").remove()
      )
    .bind('ajax:failure', (xhr, status, error) =>
        @responsePanel.html("Status: #{status}, Error: #{error}").removeClass('success').addClass('alert')
      )
    .bind('ajax:complete', () =>
        @responsePanel.show()
#        @loading.hide()

        setTimeout( =>
          @responsePanel.hide()
        , 20000)
      )