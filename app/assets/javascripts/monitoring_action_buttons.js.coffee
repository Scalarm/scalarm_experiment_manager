class window.MonitoringActionButtons
  constructor: (@extension_dialog_url, @booster_dialog_url) ->
    @actionLoading = $('#actions-loading')
    @dialog = $('#extension-dialog')

    @extendButtonListener()
    @boosterButtonListener()
    @schedulingButtonListener()
    @progressTableButtonListener()


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
