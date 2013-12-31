class window.PLGridManager
  constructor: (@dialogId) ->
    @responsePanel = $('#plgrid-login-ajax-response')
    @loading = $('#plgrid-configure-busy')

    @bindToLoginForm()
    @bindToSubmissionForm()

  bindToLoginForm: () ->
    $("#plgrid-login-form-panel form")
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
    $("#plgrid-submission-panel form")
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
