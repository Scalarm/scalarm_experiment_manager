
window.toggle_panels_on_title_click = () ->
	$('section h3.subheader').on 'click', () ->
		$section = $(this).parent()
		$content = $(this).next('.content')
		$content.toggle(400, 'swing')

		if $content.is(':visible')
			$(this).css("fontWeight", "")
		else
			$(this).css("fontWeight", "bold")
