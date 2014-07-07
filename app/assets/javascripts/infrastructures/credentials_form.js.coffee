class window.CredentialsDialog
  constructor: (@baseName, @recordId, @infrastructureName, defaultState) ->
    @bindToSubmitForm()
    @bindToRemoveButton()

    hasRecord = (@recordId? and @recordId.length > 0)
    @toggle(defaultState, null)

    @showRemoveButton(hasRecord)
    @clearForm() unless hasRecord

  toggle: (state, msg) =>
    switch state
      when 'banned'
        toastr.error(msg) if msg
        @showAlert(false)
        @showBannedAlert(true)
        @changeIcon('alert')
      when 'invalid'
        toastr.error(msg) if msg
        @showAlert(true)
        @showRemoveButton(true)
        @showBannedAlert(false)
        @changeIcon('alert')
      when 'not-in-db'
        toastr.error(msg) if msg
        @showAlert(false)
        @showProxyInfo(false)
        @showBannedAlert(false)
        @showRemoveButton(false)
        @changeIcon('lack')
      when 'unknown'
        toastr.error(msg) if msg
        @showRemoveButton(true)
        @changeIcon('alert')
      when 'proxy'
        toastr.success(msg) if msg
        @showAlert(false)
        @showProxyInfo(true)
        @showBannedAlert(false)
        @showRemoveButton(true)
        @changeIcon('ok')
      when 'ok'
        toastr.success(msg) if msg
        @showAlert(false)
        @showBannedAlert(false)
        @showRemoveButton(true)
        @changeIcon('ok')
      when 'error'
        toastr.error(msg) if msg
        @showAlert(true)
        @showBannedAlert(false)
        @changeIcon('alert')
      when 'banned'
        toastr.error(msg) if msg
        @showAlert(false)
        @showBannedAlert(true)
        @changeIcon('alert')
      when 'removed-ok'
        toastr.success(msg) if msg
        @showAlert(false)
        @showProxyInfo(false)
        @showRemoveButton(false)
        @changeIcon('lack')
        @clearForm()
        @recordId = ''
      else
        null

  bindToSubmitForm: () =>
    loading = $("##{@baseName}-busy")
    $("##{@baseName}-credentials-panel form")
      .bind('ajax:before', => loading.show())
      .bind('ajax:success', (status, data, xhr) =>
        @recordId = data.record_id if data.record_id
        @toggle(data.error_code or data.status, data.msg)
      )
      .bind('ajax:failure', (xhr, data, error) => toastr.error(data.msg))
      .bind('ajax:complete', () => loading.hide()
    )

  bindToRemoveButton: () =>
    loading = $("##{@baseName}-busy")
    $("##{@baseName}-remove-button").on "click", () =>
      $.ajax({
        type: 'POST',
        url: '/infrastructure/remove_credentials',
        data: {
          infrastructure_name: @infrastructureName,
          record_id: @recordId,
          credential_type: 'secrets'
        },

        before: =>
          loading.show()

        success: (data, status, xhr) =>
          if data.status == 'ok'
            @toggle('removed-ok', data.msg)

          else if data.status == 'error'
            toastr.error(data.msg)

          else
            toastr.error(data.msg)

        complete: =>
          loading.hide()
      })



  changeIcon: (iconName) ->
    ['alert', 'lack', 'ok'].forEach((name) =>
      $("##{@baseName}-icon-#{name}").hide()
    )
    $("##{@baseName}-icon-#{iconName}").show()

  showAlert: (visible) ->
    panel = $("##{@baseName}-alert-panel")
    visible and panel.show() or panel.hide()

  showProxyInfo: (visible) ->
    panel = $("##{@baseName}-proxy-info")
    visible and panel.show() or panel.hide()

  showBannedAlert: (visible) ->
    panel = $("##{@baseName}-banned-alert-panel")
    visible and panel.show() or panel.hide()

  showRemoveButton: (visible) ->
    panel = $("##{@baseName}-remove-panel")
    visible and panel.show() or panel.hide()

  clearForm: () ->
    $("##{@baseName}-credentials-panel :text, ##{@baseName}-credentials-panel :password").val('')
