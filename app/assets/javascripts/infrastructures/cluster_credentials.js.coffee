class window.ClusterCredentialsManager

  constructor: (@clusterCredentialsElementSelector) ->
    $("#{@clusterCredentialsElementSelector} #type").on "change", @toogleCredentialsTypeListener
    $("#{@clusterCredentialsElementSelector} #private_key_file").on "change", @readPrivateKeyFileListener

    $("#{@clusterCredentialsElementSelector} #type").val("password")
    $("#{@clusterCredentialsElementSelector} #private_key_file").val("")
    $("#{@clusterCredentialsElementSelector} #type").change()

  toogleCredentialsTypeListener: (changeEvent) =>
    credentialsType = $("#{@clusterCredentialsElementSelector} #type").val()
    $("#{@clusterCredentialsElementSelector} .credentials-specific").hide()

    $("#{@clusterCredentialsElementSelector} .#{credentialsType}-type").show()

  readPrivateKeyFileListener: (changeEvent) =>
    console.log "readPrivateKeyFile"
    f = changeEvent.target.files[0]
    console.log f

    if f
      r = new FileReader()
      r.onload = (e) =>
        contents = e.target.result
        console.log contents
        $("#{@clusterCredentialsElementSelector} #privkey").val(contents)
      r.readAsText(f)
    else
      window.Notices.show_error("Failed to load file")