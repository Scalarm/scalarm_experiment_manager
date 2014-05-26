class window.InfrastructuresBooster
  constructor: (@infrastructureName, @group, @dialogId) ->
    @dialog = $("##{dialogId}")
    @schedulerForm = $('#scheduler-form form')
    @bindToSubmissionForms()

    @infrastructureSelect = $('#infrastructure_info')
    @infrastructureSelect.change(@onInfrastructuresSelectChange)
    @onInfrastructuresSelectChange()

  onInfrastructuresSelectChange: () =>
    valueJSON = $.parseJSON(@infrastructureSelect.val())

    fieldsURL = "/infrastructure/get_booster_partial?#{$.param(valueJSON)}"
    fieldsDiv = $('#infrastructure_fields')
    fieldsDiv.html(window.loaderHTML)
    fieldsDiv.load(fieldsURL)

    smURL = "/infrastructure/simulation_managers_summary?#{$.param(valueJSON)}"
    smDiv = $('#simulation-managers')
    smDiv.html(window.loaderHTML)
    smDiv.load(smURL)


  bindToSubmissionForms: () =>
    @schedulerForm
      .bind('ajax:before', () =>
        @dialog.foundation('reveal', 'close')
        window.show_loading_notice()
      )
      .bind('ajax:success', (status, data, xhr) =>
        window.hide_notice()

        switch data.status
          when 'error', 'invalid-credentials-error', 'no-credentials-error'
            toastr.error(status.msg)
          when 'ok'
            toastr.success(status.msg)
          else
            toastr.error(status.msg)
      )