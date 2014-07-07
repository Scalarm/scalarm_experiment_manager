class window.SmDialog
  constructor: (@responseDialogId, @infrastructureName, @recordId) ->
    @dialog = $(@responseDialogId)
    @destroyDialog = $('#destroy_simulation_manager_dialog')

    $('#restart_simulation_manager_button').on 'click', =>
      window.infrastructuresTree.restartSm(@infrastructureName, @recordId)

    $('#stop_simulation_manager_button').on 'click', =>
      window.infrastructuresTree.stopSm(@infrastructureName, @recordId)

    $('#destroy_record_simulation_manager_button').on 'click', =>
      window.infrastructuresTree.destroyRecordSm(@infrastructureName, @recordId)

    $('#resource-state').load('/infrastructure/get_resource_status?' + $.param({
        infrastructure_name: @infrastructureName, record_id: @recordId
      }))

    $('.disabled :input').prop('disabled', true);
