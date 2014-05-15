class window.CredentialsDialog
  constructor: (@loginFormId, @removeFormId, @loadingImg) ->
    @loading = $(@loadingImg)
    @dialog = $(@dialog)
    @removeForm = $("##{@removeFormId} form")
    @loginForm = $("##{@loginFormId} form")

    @bindToForm("##{@loginFormId} form")
    @bindToForm("##{@removeFormId} form", (=> $("##{@loginFormId} :text, ##{@loginFormId} :password").val('')))

  bindToForm: (formIds, successFun=(->)) ->
    $(formIds)
      .bind('ajax:before', => @loading.show())
      .bind('ajax:success', (data, status, xhr) =>
        if status.status == 'error'
          toastr.error(status.msg)
        else if status.status == 'ok'
          toastr.success(status.msg)
          successFun()
      )
      .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
      .bind('ajax:complete', () => @loading.hide()
    )

