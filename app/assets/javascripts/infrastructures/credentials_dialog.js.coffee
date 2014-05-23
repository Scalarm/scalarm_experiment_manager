class window.CredentialsDialog
  constructor: (@baseName, defaultIcon) ->
    @bindToForm("##{@baseName}-credentials-panel form")
    @bindToForm("##{@baseName}-remove-panel form")

    @changeIcon(defaultIcon)
    @showAlert(defaultIcon == 'alert')

  bindToForm: (formIds) =>
    loading = $("##{@baseName}-busy")
    $(formIds)
      .bind('ajax:before', => loading.show())
      .bind('ajax:success', (data, status, xhr) =>
        if status.status == 'invalid-credentials'
          toastr.error(status.msg)
          @showAlert(true)
          $("##{@baseName}-remove-panel").show()
          @changeIcon('alert')

        else if status.status == 'not-in-db'
          toastr.error(status.msg)
          @showAlert(false)
          $("##{@baseName}-remove-panel").hide()
          @changeIcon('lack')

        else if status.status == 'removed-ok'
          toastr.success(status.msg)
          @showAlert(false)
          $("##{@baseName}-remove-panel").hide()
          $("##{@loginFormId} :text, ##{@loginFormId} :password").val('')
          @changeIcon('lack')

        else if status.status == 'added'
          toastr.success(status.msg)
          @showAlert(false)
          $("##{@baseName}-remove-panel").show()
          @changeIcon('ok')

        else if status.status == 'error'
          toastr.error(status.msg)
          @showAlert(true)
          $("##{@baseName}-remove-panel").show()
          @changeIcon('alert')
      )
      .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
      .bind('ajax:complete', () => loading.hide()
    )

  changeIcon: (iconName) ->
    ['alert', 'lack', 'ok'].forEach((name) =>
      $("##{@baseName}-icon-#{name}").hide()
    )
    $("##{@baseName}-icon-#{iconName}").show()

  showAlert: (visible) ->
    panel = $("##{@baseName}-alert-panel")
    visible and panel.show() or panel.hide()
