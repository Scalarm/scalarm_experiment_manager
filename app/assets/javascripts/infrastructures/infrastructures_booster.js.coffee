class window.InfrastructuresBooster
  constructor: (@infrastructureName, @group, @dialogId) ->
    @dialog = $("##{dialogId}")
    @schedulerForm = $('#scheduler-form form')
    @bindToSubmissionForms()
#    $('.disabled :input').prop('disabled', true)

    @loaderHTML = '<div class="row small-1 small-centered" style="margin-bottom: 10px;"><img src="/assets/loading.gif"/></div>'

    @infrastructureSelect = $('#infrastructure_info')
    @infrastructureSelect.change(@onInfrastructuresSelectChange)
    @onInfrastructuresSelectChange()

  onInfrastructuresSelectChange: () =>
    valueJSON = $.parseJSON(@infrastructureSelect.val())

    fieldsURL = "/infrastructure/get_booster_partial?#{$.param(valueJSON)}"
    fieldsDiv = $('#infrastructure_fields')
    fieldsDiv.html(@loaderHTML)
    fieldsDiv.load(fieldsURL)

    smURL = "/infrastructure/simulation_managers_summary?#{$.param(valueJSON)}"
    smDiv = $('#simulation-managers')
    smDiv.html(@loaderHTML)
    smDiv.load(smURL)


  bindToSubmissionForms: () =>
    @schedulerForm
      .bind('ajax:before', () =>
        @dialog.foundation('reveal', 'close')
        window.show_loading_notice()
      )
      .bind('ajax:success', (data, status, xhr) =>
        window.hide_notice()

        if status.status == 'error'
          toastr.error(status.msg)
        else if status.status == 'ok'
          toastr.success(status.msg)
      )