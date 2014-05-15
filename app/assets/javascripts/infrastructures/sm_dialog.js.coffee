class window.SmDialog
  constructor: (@responseDialogId) ->
    @dialog = $(@responseDialogId)

    $('.disabled :input').prop('disabled', true);

