class window.AmazonManager
  constructor: () ->
    @bindToCredentialForm()
    @bindToSubmissionForm()

    $('#amazon-ajax-response').hide()

  bindToCredentialForm: () ->
    $("#amazon-credentials-panel form")
      .bind('ajax:before', () ->
        $(this).find('.amazon-credentials-busy').show()
      )
      .bind('ajax:success', (data, status, xhr) ->
        $('#amazon-ajax-response').html('Your credentials have been updated').removeClass('alert').addClass('success')
        setTimeout("$('#amazon-ajax-response').hide()", 10000)
      )
      .bind('ajax:failure', (xhr, status, error) ->
        $('#amazon-ajax-response').html('An erroc occured').removeClass('success').addClass('alert')
        setTimeout("$('#amazon-ajax-response').hide()", 20000)
      )
      .bind('ajax:complete', () ->
        $('#amazon-ajax-response').show()
        $('.amazon-credentials-busy').hide()
      )

  bindToSubmissionForm: () ->
    $("#amazon-submission-panel form")
      .bind('ajax:before', () ->
        $('.amazon-submission-busy').show()
      )
      .bind('ajax:success', (data, response, xhr) ->
        $('#amazon-ajax-response').html(response.msg)

        if response.status == 'ok'
          $('#amazon-ajax-response').removeClass('alert').addClass('success').show()
        else if(response.status == 'error')
          $('#amazon-ajax-response').removeClass('success').addClass('alert').show()
      )
      .bind('ajax:failure', (xhr, status, error) ->
        $('#amazon-ajax-response').html('An erroc occured').removeClass('success').addClass('alert').show()
      )
      .bind('ajax:complete', () ->
        $('.amazon-submission-busy').hide()
      )