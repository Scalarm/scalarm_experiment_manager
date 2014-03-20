class window.PrivateMachinesManagerDialog
  constructor: (addMachineFormId, responseDialogId, @machinesTableId, loadingImgId) ->
    @addMachineForm = $("##{addMachineFormId} form")

    @loading = $("##{@loadingImgId}")
    @responseDialog = $("##{responseDialogId}")

    @bindToAddMachineForm()
    @bindToRemoveButtons()


  bindToAddMachineForm: () ->
    @addMachineForm
    .bind('ajax:before', => @loading.show())
    .bind('ajax:success', (data, status, xhr) => toastr.success(status.msg))
    .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
    .bind('ajax:complete', () => @loading.hide())

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

