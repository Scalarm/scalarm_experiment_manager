class window.SmDialog
  constructor: (@responseDialogId) ->
    @dialog = $(@responseDialogId)
    @destroyDialog = $('#destroy_simulation_manager_dialog')

    @destroySimulationManagerButtonListener()
    @restartSimulationManagerButtonListener()
    @destroyDialogButtonListener()

    $('.disabled :input').prop('disabled', true);

  destroySimulationManagerButtonListener: () ->
    $('#destroy_simulation_manager_button').on 'click', () =>
      @destroyDialog.foundation('reveal', 'open')
    $('#destroy_simulation_manager_dialog .no_button').on 'click', () =>
      @destroyDialog.foundation('reveal', 'close')

  destroyDialogButtonListener: () ->
    $('#destroy-yes').bind('ajax:before', () =>
      @destroyDialog.foundation('reveal', 'close')
      window.show_loading_notice()
    )
    .bind('ajax:success', (data, status, xhr) =>
      window.hide_notice()

      if status.status == 'error'
        toastr.error(status.msg)
      else if status.status == 'ok'
        toastr.success(status.msg)
    )

  restartSimulationManagerButtonListener: () ->
    $('#restart_simulation_manager_button').bind('ajax:before', () =>
      @dialog.foundation('reveal', 'close')
      window.show_loading_notice()
    )
    .bind('ajax:success', (data, status, xhr) =>
      window.hide_notice()

      if status.status == 'error'
        toastr.error(status.msg)
      else if status.status == 'ok'
        toastr.success(status.msg)
    )
