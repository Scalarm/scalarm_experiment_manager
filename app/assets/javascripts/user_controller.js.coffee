$ ->
  $("#credentials .button.radius").on "click", ->
    $("#credentials")
      .on 'valid.fndtn.abide',   -> $("#credentials .button.radius").click()
      .on 'invalid.fndtn.abide', -> $(this).find('[data-invalid]').blur()

  $('#login_username_button').on "click", ->
    $('#login_username_fieldset').toggle()
    $('#username').focus()

  new window.ExperimentLinksManager("#experiment-list-modal")