class window.Notices

  @show_loading_notice: () ->
    $('.notice').html("<div class='preloader'/>")
    $('.notice').css('height', '35px')
    $('.notice').show()
    $("html, body").animate({ scrollTop: 0 }, "slow")

  @show_notice = (message) ->
    toastr['success'](message)

  @hide_notice = () ->
    $('.notice').hide()


window.show_notice = (message) ->
  $('.notice').html(message)
  $('.notice').show()

window.hide_notice = () ->
  $('.notice').hide()

window.show_loading_notice = () ->
  $('.notice').html("<div class='preloader'/>")
  $('.notice').css('height', '35px')
  $('.notice').show()

window.show_error = (message) ->
  $('.error').html(message)
  $('.error').show()

window.hide_error = () ->
  $('.error').hide()


