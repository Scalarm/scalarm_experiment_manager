class window.Notices

  @show_loading_notice: () ->
    $('.notice').html("<div style='text-align: center'><i class=\"fa fa-refresh fa-spin fa-2x\"></i></div>")
    $('.notice').slideToggle()
    $("html, body").animate({ scrollTop: 0 }, "slow")

  @show_notice = (message) ->
    toastr['success'](message)

  @hide_notice = () ->
    $('.notice').slideToggle()
