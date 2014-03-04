
window.toggle_panels_on_title_click = () ->
	$('section h3.subheader').on 'click', () ->
		$section = $(this).parent()
		$content = $(this).next('.content')
		$header = $(this)

		$content.toggle 400, 'swing', () ->
			if $content.is ':visible'
				$header.css "fontWeight", ""
				header = $header.html()

				$header.html header.substr(0, header.indexOf(' ' + I18n.t('experiments.click_to_expand')))
			else
				$header.css "fontWeight", "bold"
				$header.html($header.html() + ' ' + I18n.t('experiments.click_to_expand'))
