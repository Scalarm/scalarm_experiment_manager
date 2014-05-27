class window.InfrastructuresBooster
  constructor: (@infrastructureName, @group, @dialogId) ->
    @dialog = $("##{dialogId}")
    @schedulerForm = $('#scheduler-form form')
    @bindToSubmissionForms()

    @infrastructureSelect = $('#infrastructure_name')
    @infrastructureSelect.change(@onInfrastructuresSelectChange)
    @onInfrastructuresSelectChange()

  onInfrastructuresSelectChange: () =>
    selectValue = @infrastructureSelect.val()
    params = $.param({infrastructure_name: selectValue})

    fieldsURL = "/infrastructure/get_booster_partial?#{params}"
    fieldsDiv = $('#infrastructure_fields')
    fieldsDiv.html(window.loaderHTML)
    fieldsDiv.load(fieldsURL)

    smURL = "/infrastructure/simulation_managers_summary?#{params}"
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
          when 'error'
            toastr.error(data.msg)
          when 'ok'
            toastr.success(data.msg)
          else
            toastr.error(data.msg)
      )