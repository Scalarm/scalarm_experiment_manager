class window.InputParameterSpaceSwitcher

  @manualSwitchOn: (event) ->
    if not $(".simulation_input .content").is(":visible")
      $(".simulation_input h3").click()

    if event.originalEvent
      $("#import-on").click()


  @manualSwitchOff: (event) ->
    if $(".simulation_input .content").is(":visible")
      $(".simulation_input h3").click()

    if event.originalEvent
      $("#import-off").click()


  @importSwitchOn: (event) ->
    if not $("#import-form .content").is(":visible")
      $("#import-form h3").click()

    if event.originalEvent
      $("#manual-on").click()


  @importSwitchOff: (event) ->
    if $("#import-form .content").is(":visible")
      $("#import-form h3").click()

    if event.originalEvent
      $("#manual-off").click()
