class window.SupervisorBooster
  constructor: (@dialogId) ->
    @dialog = $("##{dialogId}")
    @schedulerForm = $('#scheduler-form form')
#    @bindToSubmissionForms()

    @supervisorSelect = $('#supervisor_select')
    @supervisorSelect.change(@onSupervisorSelectChange)
    @onSupervisorSelectChange()

  onSupervisorSelectChange: () =>
    selectValue = @supervisorSelect.val()
    console.log(selectValue)

    if selectValue != 'none'
      fieldsURL = "http://localhost:13337/supervisors/#{selectValue}/start_panel"
      fieldsDiv = $('#supervisor_fields')
      fieldsDiv.html(window.loaderHTML)
      fieldsDiv.load(fieldsURL)



#  bindToSubmissionForms: () =>
#    @schedulerForm
#    .bind('ajax:before', () =>
#      @dialog.foundation('reveal', 'close')
#      window.Notices.show_loading_notice()
#    )
#    .bind('ajax:success', (status, data, xhr) =>
#      switch data.status
#        when 'error'
#          toastr.error(data.msg)
#        when 'ok'
#          toastr.success(data.msg)
#        else
#          toastr.error(data.msg)
#    )
#    .bind('ajax:error', (xhr, data, error) =>
#      resp = data.responseJSON
#      toastr.error(resp and (resp.reason or resp.msg) or "Unknown error - please contact administrators.")
#    )
#    .bind('ajax:complete', =>
#      window.Notices.hide_notice()
#      window.infrastructuresTree and window.infrastructuresTree.updateInfrastructureNode(@infrastructureName)
#      window.retrieveComputationalResourcesSummary and window.retrieveComputationalResourcesSummary()
#    )
