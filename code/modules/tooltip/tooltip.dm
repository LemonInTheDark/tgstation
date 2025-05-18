/*
Usage:
- Define mouse event procs on your (probably HUD) object and simply call the show and hide procs respectively:
	/atom/movable/screen/hud
		MouseEntered(location, control, params)
			usr.client.tooltip.show(params, title = src.name, content = src.desc)

		MouseExited()
			usr.client.tooltip.hide()

Customization:
- Theming can be done by passing the theme var to show() and using css in the html file to change the look
- For your convenience some pre-made themes are included

Notes:
- You may have noticed 90% of the work is done via javascript on the client. Gotta save those cycles man.
*/


/datum/tooltip
	var/client/owner
	var/control = "mainwindow.tooltip"
	var/showing = 0
	var/queueHide = 0
	var/init = 0
	var/atom/last_target


/datum/tooltip/New(client/C)
	if (C)
		owner = C
		var/datum/asset/stuff = get_asset_datum(/datum/asset/simple/jquery)
		stuff.send(owner)
		var/datum/asset/spritesheet_batched/pip_asset = get_asset_datum(/datum/asset/spritesheet/storage_pips)
		pip_asset.send(owner)
		owner << browse(file2text('code/modules/tooltip/tooltip.html'), "window=[control]")
	..()


/datum/tooltip/proc/show(atom/movable/thing, params = null, title = null, content = null, theme = "default", special = "none")
	if (!thing || !params || (!title && !content) || !owner || !isnum(ICON_SIZE_ALL))
		return FALSE

	if (!isnull(last_target))
		UnregisterSignal(last_target, COMSIG_QDELETING)

	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_target_qdel))

	last_target = thing

	if (!init)
		//Initialize some vars
		init = 1
		owner << output(list2params(list(ICON_SIZE_ALL, control)), "[control]:tooltip.init")

	showing = 1

	var/draw_title = !!title
	var/draw_content = !!content
	if (draw_content)
		title = "<h1>[title]</h1>"
	else
		title = "<p>[title]</p>"
	content = "<p>[content]</p>"

	// Strip macros from item names
	title = replacetext(title, "\proper", "")
	title = replacetext(title, "\improper", "")
	var/drawn_text = ""
	if(draw_title)
		drawn_text += title
	if(draw_content)
		drawn_text += content

	//Make our dumb param object
	params = {"{ "cursor": "[params]", "screenLoc": "[thing.screen_loc]" }"}

	//Send stuff to the tooltip
	var/view_size = getviewsize(owner.view)
	owner << output(list2params(list(params, view_size[1] , view_size[2], drawn_text, theme, special)), "[control]:tooltip.update")

	//If a hide() was hit while we were showing, run hide() again to avoid stuck tooltips
	showing = 0
	if (queueHide)
		hide()

	return TRUE


/datum/tooltip/proc/hide()
	queueHide = showing ? TRUE : FALSE

	if (queueHide)
		addtimer(CALLBACK(src, PROC_REF(do_hide)), 0.1 SECONDS)
	else
		do_hide()

	return TRUE

/datum/tooltip/proc/on_target_qdel()
	SIGNAL_HANDLER

	INVOKE_ASYNC(src, PROC_REF(hide))
	last_target = null

/datum/tooltip/proc/do_hide()
	winshow(owner, control, FALSE)

/datum/tooltip/Destroy(force)
	last_target = null
	return ..()

//Open a tooltip for user, at a location based on params
//Theme is a CSS class in tooltip.html, by default this wrapper chooses a CSS class based on the user's UI_style (Midnight, Plasmafire, Retro, etc)
//Includes sanity.checks
/proc/openToolTip(mob/user = null, atom/movable/tip_src = null, params = null, title = "", content = "", theme = "")
	if(!istype(user) || !user.client?.tooltips)
		return
	if(!theme)
		theme = get_tooltip_theme(user.client)
	user.client.tooltips.show(tip_src, params, title, content, theme)

/proc/get_tooltip_theme(client/theme_from)
	var/icon = get_tooltip_theme_icon(theme_from)
	if(icon)
		return LOWER_TEXT(icon)
	return "default"

/proc/get_tooltip_theme_icon(client/theme_from)
	var/ui_style = theme_from?.prefs?.read_preference(/datum/preference/choiced/ui_style)
	if(ui_style)
		return LOWER_TEXT(ui_style)
	return null

/proc/get_tooltip_weight_span(w_class, client/theme_from)
	var/theme = get_tooltip_theme(theme_from)
	var/datum/asset/spritesheet_batched/pip_asset = get_asset_datum(/datum/asset/spritesheet/storage_pips)
	return pip_asset.icon_tag(sanitize_css_class_name("[theme][w_class]"))

//Arbitrarily close a user's tooltip
//Includes sanity checks.
/proc/closeToolTip(mob/user)
	if(!istype(user) || !user.client?.tooltips)
		return
	user.client.tooltips.hide()


