/datum/asset/spritesheet/storage_pips
	name = "storage_pips"
	legacy = TRUE

#define PIP_WIDTH 4
#define PIP_HEIGHT 4

/datum/asset/spritesheet/storage_pips/create_spritesheets()
	for (var/style_name in GLOB.available_ui_styles)
		var/icon/style_icon = GLOB.available_ui_styles[style_name]
		for(var/weight in 1 to WEIGHT_CLASS_MAX)
			var/icon/pip_icon = icon(style_icon, "pip_full")
			var/icon/final_icon = icon(style_icon, "pip_full")

			var/width = PIP_WIDTH + (weight - 1) * (PIP_WIDTH + 1)
			var/height = PIP_HEIGHT
			final_icon.Crop(1, 1, width, height)
			for(var/i in 1 to (weight - 1)) // one is already drawn
				// + 1 to add a buffer
				final_icon.Blend(pip_icon, ICON_OVERLAY, x = i * (PIP_WIDTH + 1) + 1, y = 1)
			width = width * 3
			height = height * 3
			final_icon.Scale(width, height)

			var/id = sanitize_css_class_name("[LOWER_TEXT(style_name)]-[weight]")
			Insert(id, final_icon)
