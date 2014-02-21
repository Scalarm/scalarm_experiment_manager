class window.ImagesManager
  constructor: (@dialogId) ->
    @responsePanel = $('#images_manager-ajax-response')
    @cloudSelect = $('#cloud-select select')
    @loading = $('.images_manager-busy')
    @loading_submit = $('.image-submission-busy')
    @bindToRemoveButton()
    @cloudSelect.change(@cloudChanged)
    @cloudChanged()

#    $('#images_manager-ajax-response').hide()

  cloudChanged: =>
    $('div[id^="image-id-row-"]').hide()
    $('div[id^="image-id-row-"] select, input').prop('disabled', true)

    cloudName = @cloudSelect.val()
    $("#image-id-row-#{cloudName}").show()
    $("#image-id-row-#{cloudName} select, input").prop('disabled', false)

  bindToSubmissionForm: () ->
    $("#amazon-submission-panel form")
    .bind('ajax:before', () =>
        $(@dialogId).foundation('reveal', 'close')
        window.show_loading_notice()
      )
    .bind('ajax:success', (data, status, xhr) ->
        window.hide_notice()

        if status.status == 'error'
          window.show_error(status.msg)
        else if status.status == 'ok'
          window.show_notice(status.msg)
      )

  bindToRemoveButton: =>
    $(".images form")
    .bind('ajax:before', =>
#        @loading.show()
        @responsePanel.html('')
      )
    .bind('ajax:success', (data, status, xhr) =>
#        @responsePanel.html(status.msg).removeClass('alert').addClass('success')
        @responsePanel.html(status.msg)
        $("##{status.cloud_name}-#{status.image_id}").remove()
      )
#    .bind('ajax:failure', (xhr, status, error) =>
#        @responsePanel.show()
#        @responsePanel.html("Status: #{status}, Error: #{error}").removeClass('success').addClass('alert')
#      )
    .bind('ajax:complete', () =>
        @responsePanel.show()
#        @loading.hide()

        setTimeout( =>
          @responsePanel.hide()
        , 5000)
      )