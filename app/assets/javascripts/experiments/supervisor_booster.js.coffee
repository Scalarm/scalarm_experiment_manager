class window.SupervisorBooster
  constructor: (@es_url) ->
    @supervisorSelect = $('#supervisor_select')
    @supervisorSelect.change(@onSupervisorSelectChange)
    @onSupervisorSelectChange()

  onSupervisorSelectChange: () =>
    selectValue = @supervisorSelect.val()
    if selectValue != 'none'
      fieldsURL = "https://#{@es_url}/supervisors/#{selectValue}/start_panel"
      fieldsDiv = $('#supervisor_fields')
      fieldsDiv.html(window.loaderHTML)

      $.ajax({
        url: fieldsURL,
        xhrFields: {
          withCredentials: true
        },
        success: (data, textStatus, jqXHR) =>
          fieldsDiv.html(data)
      })

      $('#input-space-parameters').hide();
      $('#check-experiment-size').hide();
      $('#supervisor_fields').show();
    else
      $('#supervisor_fields').empty();
      $('#input-space-parameters').show();
      $('#check-experiment-size').show();

