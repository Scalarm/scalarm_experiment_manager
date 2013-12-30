class window.PLCloudManager
  constructor: () ->
    @bindToCredentialForm()
    @bindToSubmissionForm()

    $('#plcloud-ajax-response').hide()

  bindToCredentialForm: () ->
    $("#plcloud-credentials form")
      .bind('ajax:before', () ->
        $(this).find('.plcloud-credentials-busy').show()
      )
      .bind('ajax:success', (data, status, xhr) ->
        $('#plcloud-ajax-response').html('Your credentials have been updated').removeClass('alert').addClass('success')
        setTimeout("$('#plcloud-ajax-response').hide()", 10000)
      )
      .bind('ajax:failure', (xhr, status, error) ->
        $('#plcloud-ajax-response').html('An erroc occured').removeClass('success').addClass('alert')
        setTimeout("$('#plcloud-ajax-response').hide()", 20000)
      )
      .bind('ajax:complete', () ->
        $('#plcloud-ajax-response').show()
        $('.plcloud-credentials-busy').hide()
      )

  bindToSubmissionForm: () ->
    $("#plcloud-submission-tab form")
      .bind('ajax:before', () ->
        $('.plcloud-submission-busy').show()
      )
      .bind('ajax:success', (data, response, xhr) ->
        $('#plcloud-ajax-response').html(response.msg)

        if response.status == 'ok'
          $('#plcloud-ajax-response').removeClass('alert').addClass('success').show()
        else if(response.status == 'error')
          $('#plcloud-ajax-response').removeClass('success').addClass('alert').show()
      )
      .bind('ajax:failure', (xhr, status, error) ->
        $('#plcloud-ajax-response').html('An erroc occured').removeClass('success').addClass('alert').show()
      )
      .bind('ajax:complete', () ->
        $('.plcloud-submission-busy').hide()
      )