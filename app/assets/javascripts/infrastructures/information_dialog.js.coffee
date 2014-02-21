class window.InformationDialog
  constructor: (@loginFormId, @submissionFormId, @responseDialog, @loadingImg) ->
    @loading = $(@loadingImg)
    @responseDialog = $(@responseDialog)

    @bindToLoginForm()
    @bindToSubmissionForm()

  bindToLoginForm: () ->
    $("##{@loginFormId} form")
      .bind('ajax:before', => @loading.show())
      .bind('ajax:success', (data, status, xhr) => toastr.success(status.msg))
      .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
      .bind('ajax:complete', () => @loading.hide())

  bindToSubmissionForm: () ->
    $("##{@submissionFormId} form")
      .bind('ajax:before', () =>
        @responseDialog.foundation('reveal', 'close')
        window.show_loading_notice()
      )
      .bind 'ajax:success', (data, status, xhr) ->
        window.hide_notice()

        if status.status == 'error'
          toastr.error(status.msg)
        else if status.status == 'ok'
          toastr.success(status.msg)
