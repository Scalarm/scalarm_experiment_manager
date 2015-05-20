class window.SupervisorBooster
  constructor: () ->
    @supervisorSelect = $('#supervisor_select')
    @supervisorSelect.change(@onSupervisorSelectChange)
    @onSupervisorSelectChange()

  onSupervisorSelectChange: () =>
    selectValue = @supervisorSelect.val()
    if selectValue != 'none'
      fieldsURL = "http://localhost:13337/supervisors/#{selectValue}/start_panel"
      fieldsDiv = $('#supervisor_fields')
      fieldsDiv.html(window.loaderHTML)
      fieldsDiv.load(fieldsURL)
      $('#input-space-parameters').hide();
      $('#check-experiment-size').hide();
      $('#supervisor_fields').show();
    else
      $('#supervisor_fields').empty();
      $('#input-space-parameters').show();
      $('#check-experiment-size').show();

