class window.SupervisorBooster
  constructor: (@es_url) ->
    @supervisorSelect = $('#supervisor_select')
    @supervisorSelect.change(@onSupervisorSelectChange)
    @onSupervisorSelectChange()
    @fieldsDiv = $('#supervisor_fields')
    @loaderDir = $('#supervisor_form_loader')

  showLoader: () =>
    @loaderDir.html(window.loaderHTML)

  hideLoader: () =>
    @loaderDir.empty()

  onSupervisorSelectChange: () =>
    selectValue = @supervisorSelect.val()
    if selectValue && selectValue != 'none'
      fieldsURL = "https://#{@es_url}/supervisors/#{selectValue}/start_panel"

      try
        $.ajax({
          url: fieldsURL,
          xhrFields: {
            withCredentials: true
          },
          success: ((data, textStatus, jqXHR) =>
            @fieldsDiv.html(data)
          ),
          error: ((jqXHR, textStatus, errorThrown) =>
            @fieldsDiv.html("There was a problem fetching this method's configuration: #{errorThrown}")
          ),
          complete: (=>
            @hideLoader()
          )
        })

        $('#input-space-parameters').hide()
        $('#check-experiment-size').hide()
        $('#supervisor_fields').show()

      catch error
        @hideLoader()

    else
      $('#supervisor_fields').empty()
      $('#input-space-parameters').show()
      $('#check-experiment-size').show()

