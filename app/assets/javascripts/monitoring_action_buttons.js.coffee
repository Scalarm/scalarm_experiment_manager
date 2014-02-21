class window.MonitoringActionButtons
  constructor: (@extension_dialog_url, @booster_dialog_url) ->
    @actionLoading = $('#actions-loading')
    @dialog = $('#extension-dialog')

    @extendButtonListener()
    @boosterButtonListener()
    @schedulingButtonListener()
    @progressTableButtonListener()
    @stopExperimentButtonListener()
    @destroyExperimentButtonListener()


  extendButtonListener: () ->
    # handling ajax loading of the Extension dialog
    $('#extensionDialogOpenButton').on 'click', () =>
      @actionLoading.show()
      @dialog.load @extension_dialog_url, () =>
        @actionLoading.hide()
        @dialog.foundation('reveal', 'open')

  boosterButtonListener: () ->
    $('#boostButton').on 'click', () =>
      @actionLoading.show()
      @dialog.load @booster_dialog_url, () =>
        @actionLoading.hide()
        @dialog.foundation('reveal', 'open')

  schedulingButtonListener: () ->
    $('#schedulingButton').on 'click', () =>
      $('#scheduling_policy_dialog').foundation('reveal', 'open')
      $('#scheduling-ajax-response').html('')

  progressTableButtonListener: () ->
    $('#progressButton').on 'click', () =>
      $('#progressInformationWrapper').slideToggle()
      $('html, body').animate({ scrollTop: $('#progressInformationWrapper').offset().top }, 1000)

  stopExperimentButtonListener: () ->
    $('#stopExperimentButton').on 'click', () =>
      $('#stop_experiment_dialog').foundation('reveal', 'open')
    $('#stop_experiment_dialog .no_button').on 'click', () =>
      $('#stop_experiment_dialog').foundation('reveal', 'close')

  destroyExperimentButtonListener: () ->
    $('#destroyExperimentButton').on 'click', () =>
      $('#destroy_experiment_dialog').foundation('reveal', 'open')
    $('#destroy_experiment_dialog .no_button').on 'click', () =>
      $('#destroy_experiment_dialog').foundation('reveal', 'close')
