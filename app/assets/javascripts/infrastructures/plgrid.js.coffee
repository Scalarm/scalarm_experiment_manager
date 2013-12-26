class window.PLGridManager
  constructor: (@dialogId) ->
    @bindToLoginForm()
    @bindToSubmissionForm()

  bindToLoginForm: () ->
    $("#plgrid-login-form-panel form")
      .bind('ajax:before', () ->
          $('#plgrid-configure-busy').show()
          $('#plgrid-login-ajax-response').html('')
      )
      .bind('ajax:success', (data, status, xhr) ->
        $('#plgrid-login-ajax-response').html(status.msg).removeClass('alert').addClass('success').show()
      )
      .bind('ajax:failure', (xhr, status, error) ->
        $('#plgrid-login-ajax-response').html('An erroc occured').removeClass('success').addClass('alert').show()
      )
      .bind('ajax:complete', () ->
        $('#plgrid-configure-busy').hide()
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
