class window.InputParameterSpaceSwitcher

  @manualSwitchOn: (event) ->
    $("#manual-off").addClass("clicked");
    $("#manual-on").removeClass("clicked");

    if not $(".simulation_input .content").is(":visible")
      $(".simulation_input h3").click()

    if event.originalEvent
      $("#import-on").click()


  @manualSwitchOff: (event) ->
    $("#manual-on").addClass("clicked");
    $("#manual-off").removeClass("clicked");

    if $(".simulation_input .content").is(":visible")
      $(".simulation_input h3").click()

    if event.originalEvent
      $("#import-off").click()


  @importSwitchOn: (event) ->
    $("#import-off").addClass("clicked");
    $("#import-on").removeClass("clicked");

    if not $("#import-form .content").is(":visible")
      $("#import-form h3").click()

    if event.originalEvent
      $("#manual-on").click()


  @importSwitchOff: (event) ->
    $("#import-on").addClass("clicked");
    $("#import-off").removeClass("clicked");

    if $("#import-form .content").is(":visible")
      $("#import-form h3").click()

    if event.originalEvent
      $("#manual-off").click()
