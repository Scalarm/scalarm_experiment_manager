$ ->
  $("#credentials .button.radius").on "click", ->
    $("#credentials")
      .on 'valid.fndtn.abide',   -> $("#credentials .button.radius").click()
      .on 'invalid.fndtn.abide', -> $(this).find('[data-invalid]').blur()
