class window.ImagesManagerDialog
  constructor: (@addImagePanelId, @cloudSelectId, @responseDialog, @loadingImg) ->
    @addImageForm = $("##{@addImagePanelId} form")
    @cloudSelect = $("#{@cloudSelectId} select")
    @loading = $(@loadingImg)
    @responseDialog = $(@responseDialog)

    if @cloudSelect.length <= 0 or (@cloudSelect.length == 1 and @cloudSelect[0].length == 0)
      $("##{@addImageFormId} form :input").prop('disabled', true)

    @bindToAddImageForm()
    @bindToRemoveButtons()

    @cloudSelect.change(@cloudChanged)
    @cloudChanged()


  bindToAddImageForm: () ->
    @addImageForm
    .bind('ajax:before', => @loading.show())
    .bind('ajax:success', (data, status, xhr) => toastr.success(status.msg))
    .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
    .bind('ajax:complete', () =>
        @loading.hide()
        window.location = "/user_controller/account?active_tab=images_manager##{@addImagePanelId}"
      )

  cloudChanged: =>
    $('div[id^="image-id-row-"]').hide()
    $('div[id^="image-id-row-"] select').prop('disabled', true)
    $('div[id^="image-id-row-"] input').prop('disabled', true)

    cloudName = @cloudSelect.val()
    $("#image-id-row-#{cloudName}").show()
    $("#image-id-row-#{cloudName} select").prop('disabled', false)
    $("#image-id-row-#{cloudName} input").prop('disabled', false)

  bindToRemoveButtons: ->
    $(".images tr[id]").each( ->
      row_id = this['id']
      row_loading = $(".#{row_id}-busy")
      $("##{row_id} form")
      .bind('ajax:before', => row_loading.show())
      .bind('ajax:success', (data, status, xhr) =>
          toastr.success(status.msg)
          $("##{row_id}").remove()
        )
      .bind('ajax:failure', (xhr, status, error) => toastr.error(status.msg))
      .bind('ajax:complete', () => row_loading.hide())
    );

