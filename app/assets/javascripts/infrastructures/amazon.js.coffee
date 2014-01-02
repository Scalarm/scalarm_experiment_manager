class window.AmazonManager
  constructor: (@dialogId) ->
    @responsePanel = $('#amazon-ajax-response')
    @loading = $('.amazon-credentials-busy')
    @bindToCredentialForm()
    @bindToSubmissionForm()

    $('#plcloud-ajax-response').hide()

  bindToCredentialForm: =>
    $("#amazon-credentials form")
      .bind('ajax:before', =>
        @loading.show()
        @responsePanel.html('')
      )
      .bind('ajax:success', (data, status, xhr) =>
        @responsePanel.html(status.msg).removeClass('alert').addClass('success')
      )
      .bind('ajax:failure', (xhr, status, error) =>
        @responsePanel.html("Status: #{status}, Error: #{error}").removeClass('success').addClass('alert')
      )
      .bind('ajax:complete', () =>
        @responsePanel.show()
        @loading.hide()

        setTimeout( =>
          @responsePanel.hide()
        , 20000)
      )

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
