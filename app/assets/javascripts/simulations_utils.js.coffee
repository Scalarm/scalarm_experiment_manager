# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

window.readParameterSpaceFile = (event) ->
  console.log "Reading files"
  if event.target.files.length > 0
    file = event.target.files[0]

    reader = new FileReader()
    reader.onload = (f) ->
      console.log f.target.result

    reader.readAsText(file)

window.importClick = () ->
  file = document.getElementById('parameter_space_file').files[0]
  if file != undefined
    reader = new FileReader()
    reader.onload = (f) ->
      file_content = f.target.result

      $.ajax window.import_file_url,
        method: 'POST',
        data: {
          file_content: file_content,
          simulation_id: $('#simulation_id').val()
        },
        success: (data, status, xhr) ->
#          console.log data
#          console.log status
#          console.log xhr
          $("#parameter_selection").html(data.columns)
          $('#check-imported-experiment-size').removeClass('disabled')
          $("#import form input[type='submit']").removeAttr('disabled')

    reader.readAsText(file)
  else
    alert "You must select a file"

window.checkImportedSize = () ->
  console.log 'Imported clicked'
  $btn = $(this)

  unless $btn.hasClass('disabled')
    file = document.getElementById('parameter_space_file').files[0]

    if file != undefined
      reader = new FileReader()
      reader.onload = (f) ->
        file_content = f.target.result

        data = 
          file_content: file_content
          simulation_id: $('#simulation_id').val()
          replication_level: $('#import-form #replication_level').val()

        $("input[id^='param_']:checked").each (index, element) -> data[$(element).attr('id')] = 1

        $.ajax $('#imported-experiment-size-url').val(),
          method: 'POST',
          data: data,
          beforeSend: () ->
            $('#conduct-import-loading').show()
          success: (data, status, xhr) ->
            $('#conduct-import-loading').hide()
            $("#experiment-size-dialog #calculated-experiment-size").html(data.experiment_size)
            $('#experiment-size-dialog').foundation('reveal', 'open')
          error: (msg) ->
            toastr.error(msg)
            $('#conduct-import-loading').hide()

      reader.readAsText(file)

window.bindImportParameterSpaceListeners = (url) ->
  window.import_file_url = url
  document.getElementById('import_submit').addEventListener('click', window.importClick, false)
  document.getElementById('check-imported-experiment-size').addEventListener('click', window.checkImportedSize, false)
