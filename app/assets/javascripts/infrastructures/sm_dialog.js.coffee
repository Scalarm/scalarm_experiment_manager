class window.SmDialog
  constructor: (@responseDialogId) ->
    @responseDialog = $(@responseDialogId)

    $('.disabled :input').prop('disabled', true);

