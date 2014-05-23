class window.PrivateMachinesManagerDialog
  constructor: (@addMachinePanelId, responseDialogId, @machinesTableId, loadingImgId) ->
    @addMachineForm = $("##{addMachinePanelId} form")

    @loading = $("##{@loadingImgId}")
    @dialog = $("##{responseDialogId}")

    @bindToAddMachineForm()
    @bindToRemoveButtons()


  bindToAddMachineForm: () ->
    @addMachineForm
    .bind('ajax:before', => @loading.show())
    .bind('ajax:success', (data, status, xhr) =>
      if status.status == 'error'
        toastr.error(status.msg)
      else if status.status == 'ok'
        toastr.success(status.msg)
    )
    .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
    .bind('ajax:complete', () =>
        @loading.hide()
        window.location = "/user_controller/account?active_tab=private_machines_manager##{@addMachinePanelId}"
      )

  bindToRemoveButtons: ->
    $("##{@machinesTableId} tr[id]").each( ->
      row_id = this['id']
      row_loading = $(".#{row_id}-busy")
      $("##{row_id} form")
      .bind('ajax:before', => row_loading.show())
      .bind('ajax:success', (data, status, xhr) =>
          toastr.success(status.msg)
          $("##{row_id}").remove()
        )
      .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
      .bind('ajax:complete', () => row_loading.hide())
    );

