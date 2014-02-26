class window.InformationDialog
  constructor: (@responseDialogId) ->
    @responseDialog = $(@responseDialogId)

    @bindToSubmissionForms()

    $('.disabled :input').prop('disabled', true);

  bindToSubmissionForms: () ->
    $responseDialog = @responseDialog
    $("div[id^=\"submission-panel-\"]").each( ->
      panel_id = this['id']
      $("##{panel_id} form")
      .bind('ajax:before', () ->
        $responseDialog.foundation('reveal', 'close')
        window.show_loading_notice()
      )

      .bind('ajax:success', (data, status, xhr) ->
        window.hide_notice()

        if status.status == 'error'
          toastr.error(status.msg)
        else if status.status == 'ok'
          toastr.success(status.msg)
      )
    )
