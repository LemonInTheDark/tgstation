
/datum/hud/proc/create_parallax(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob.client

	if (!apply_parallax_pref(viewmob)) //don't want shit computers to crash when specing someone with insane parallax, so use the viewer's pref
		for(var/atom/movable/screen/plane_master/parallax as anything in get_true_plane_masters(PLANE_SPACE_PARALLAX))
			parallax.hide_plane(screenmob)
		return

	for(var/atom/movable/screen/plane_master/parallax as anything in get_true_plane_masters(PLANE_SPACE_PARALLAX))
		parallax.unhide_plane(screenmob)

	if(!C.parallax_rock)
		C.parallax_rock = new(null, src)
		C.screen += C.parallax_rock

	if(!length(C.parallax_layers_cached))
		C.parallax_layers_cached = list()
		C.parallax_layers_cached += new /atom/movable/screen/parallax_layer/layer_1(null, src)
		C.parallax_layers_cached += new /atom/movable/screen/parallax_layer/layer_2(null, src)
		C.parallax_layers_cached += new /atom/movable/screen/parallax_layer/planet(null, src)
		if(SSparallax.random_layer)
			C.parallax_layers_cached += new SSparallax.random_layer.type(null, src, FALSE, SSparallax.random_layer)
		C.parallax_layers_cached += new /atom/movable/screen/parallax_layer/layer_3(null, src)

	C.parallax_layers = C.parallax_layers_cached.Copy()

	if (length(C.parallax_layers) > C.parallax_layers_max)
		C.parallax_layers.len = C.parallax_layers_max

	C.parallax_rock.vis_contents = C.parallax_layers
	// We could do not do parallax for anything except the main plane group
	// This could be changed, but it would require refactoring this whole thing
	// And adding non client particular hooks for all the inputs, and I do not have the time I'm sorry :(
	for(var/atom/movable/screen/plane_master/plane_master as anything in screenmob.hud_used.get_true_plane_masters(PLANE_SPACE))
		if(screenmob != mymob)
			C.screen -= locate(/atom/movable/screen/plane_master/parallax_white) in C.screen
			C.screen += plane_master
		plane_master.color = list(
			0, 0, 0, 0,
			0, 0, 0, 0,
			0, 0, 0, 0,
			1, 1, 1, 1,
			0, 0, 0, 0
			)

/datum/hud/proc/remove_parallax(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob.client
	C.screen -= (C.parallax_layers_cached)
	for(var/atom/movable/screen/plane_master/plane_master as anything in screenmob.hud_used.get_true_plane_masters(PLANE_SPACE))
		if(screenmob != mymob)
			C.screen -= locate(/atom/movable/screen/plane_master/parallax_white) in C.screen
			C.screen += plane_master
		plane_master.color = initial(plane_master.color)
	C.parallax_layers = null

/datum/hud/proc/apply_parallax_pref(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	var/turf/screen_location = get_turf(screenmob)

	if(SSmapping.level_trait(screen_location?.z, ZTRAIT_NOPARALLAX))
		for(var/atom/movable/screen/plane_master/white_space as anything in get_true_plane_masters(PLANE_SPACE))
			white_space.hide_plane(screenmob)
		return FALSE

	for(var/atom/movable/screen/plane_master/white_space as anything in get_true_plane_masters(PLANE_SPACE))
		white_space.unhide_plane(screenmob)

	if (SSlag_switch.measures[DISABLE_PARALLAX] && !HAS_TRAIT(viewmob, TRAIT_BYPASS_MEASURES))
		return FALSE

	var/client/C = screenmob.client
	// Default to HIGH
	var/parallax_selection = C?.prefs.read_preference(/datum/preference/choiced/parallax) || PARALLAX_HIGH

	switch(parallax_selection)
		if (PARALLAX_INSANE)
			C.parallax_layers_max = 5
			C.do_parallax_animations = TRUE
			return TRUE

		if(PARALLAX_HIGH)
			C.parallax_layers_max = 4
			C.do_parallax_animations = TRUE
			return TRUE

		if (PARALLAX_MED)
			C.parallax_layers_max = 3
			C.do_parallax_animations = TRUE
			return TRUE

		if (PARALLAX_LOW)
			C.parallax_layers_max = 1
			C.do_parallax_animations = FALSE
			return TRUE

		if (PARALLAX_DISABLE)
			return FALSE

/datum/hud/proc/update_parallax_pref(mob/viewmob)
	var/mob/screen_mob = viewmob || mymob
	if(!screen_mob.client)
		return
	remove_parallax(screen_mob)
	create_parallax(screen_mob)
	update_parallax(screen_mob)

// This sets which way the current shuttle is moving (returns true if the shuttle has stopped moving so the caller can append their animation)
/datum/hud/proc/set_parallax_movedir(new_parallax_movedir = 0, skip_windups, mob/viewmob)
	. = FALSE
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob.client
	if(new_parallax_movedir == C.parallax_movedir)
		return
	var/animatedir = new_parallax_movedir
	if(new_parallax_movedir == FALSE)
		var/animate_time = 0
		for(var/atom/movable/screen/parallax_layer/layer as anything in C.parallax_layers)
			layer.icon_state = initial(layer.icon_state)
			layer.update_o(C.view)
			var/T = PARALLAX_LOOP_TIME / layer.speed
			if (T > animate_time)
				animate_time = T
		C.dont_animate_parallax = world.time + min(animate_time, PARALLAX_LOOP_TIME)
		animatedir = C.parallax_movedir

	var/target_x = 0
	var/target_y = 0
	switch(animatedir)
		if(NORTH)
			target_y = 480
		if(SOUTH)
			target_y = -480
		if(EAST)
			target_x = 480
		if(WEST)
			target_x = -480

	var/shortesttimer
	if(!skip_windups)
		for(var/atom/movable/screen/parallax_layer/layer as anything in C.parallax_layers)
			var/T = PARALLAX_LOOP_TIME / layer.speed
			if (isnull(shortesttimer))
				shortesttimer = T
			if (T < shortesttimer)
				shortesttimer = T
			layer.pixel_x = target_x
			layer.pixel_y = target_y
			animate(layer, pixel_x = 0, pixel_y = 0, time = T, easing = QUAD_EASING | (new_parallax_movedir ? EASE_IN : EASE_OUT), flags = ANIMATION_END_NOW)
			#warn this should just be a looping animate
			if (new_parallax_movedir)
				layer.pixel_x = target_x
				layer.pixel_y = target_y
				animate(pixel_x = 0, pixel_y = 0, time = T) //queue up another animate so lag doesn't create a shutter

	C.parallax_movedir = new_parallax_movedir
	if (C.parallax_animate_timer)
		deltimer(C.parallax_animate_timer)
	var/datum/callback/CB = CALLBACK(src, PROC_REF(update_parallax_motionblur), C, animatedir, new_parallax_movedir, target_x, target_y)
	if(skip_windups)
		CB.Invoke()
	else
		C.parallax_animate_timer = addtimer(CB, min(shortesttimer, PARALLAX_LOOP_TIME), TIMER_CLIENT_TIME|TIMER_STOPPABLE)


/datum/hud/proc/update_parallax_motionblur(client/C, animatedir, new_parallax_movedir, target_x, target_y)
	if(!C)
		return
	C.parallax_animate_timer = FALSE
	for(var/atom/movable/screen/parallax_layer/layer as anything in C.parallax_layers)
		if (!new_parallax_movedir)
			animate(layer)
			continue

		var/newstate = initial(layer.icon_state)
		var/T = PARALLAX_LOOP_TIME / layer.speed

		if (newstate in icon_states(layer.icon))
			layer.icon_state = newstate
			layer.update_o(C.view)

		layer.pixel_x = target_x
		layer.pixel_y = target_y

		animate(layer, pixel_x = target_x, pixel_y = target_y, time = 0, loop = -1, flags = ANIMATION_END_NOW)
		animate(pixel_x = 0, pixel_y = 0, time = T)

GLOBAL_LIST_EMPTY(parallax_cost)
GLOBAL_LIST_EMPTY(parallax_count)
/datum/hud/proc/update_parallax(mob/viewmob)
	INIT_COST(GLOB.parallax_cost, GLOB.parallax_count)
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob.client
	var/turf/posobj = get_turf(C.eye)
	if(!posobj)
		return

	var/area/areaobj = posobj.loc
	SET_COST("initial setup")
	// Update the movement direction of the parallax if necessary (for shuttles)
	set_parallax_movedir(areaobj.parallax_movedir, FALSE, screenmob)
	SET_COST("set movedir")

	var/force = FALSE
	if(!C.previous_turf || (C.previous_turf.z != posobj.z))
		C.previous_turf = posobj
		force = TRUE
	SET_COST("pull previous turf")

	//Doing it this way prevents parallax layers from "jumping" when you change Z-Levels.
	var/offset_x = posobj.x - C.previous_turf.x
	var/offset_y = posobj.y - C.previous_turf.y
	SET_COST("calc offsets")

	if(!offset_x && !offset_y && !force)
		return

	SET_COST("check offsets")
	var/glide_rate = round(world.icon_size / screenmob.glide_size * world.tick_lag, world.tick_lag)
	SET_COST("build glide rate")
	C.previous_turf = posobj
	SET_COST("set previous turf")

	var/largest_change = max(abs(offset_x), abs(offset_y))
	SET_COST("calc largest change")
	var/max_allowed_dist = (glide_rate / world.tick_lag) + 1
	SET_COST("calc max allowed dist")
	// If we aren't already moving/don't allow parallax, have made some movement, and that movement was smaller then our "glide" size, animate
	var/run_parralax = (C.do_parallax_animations && glide_rate && !areaobj.parallax_movedir && C.dont_animate_parallax <= world.time && largest_change <= max_allowed_dist)
	SET_COST("calc run parallax")

	for(var/atom/movable/screen/parallax_layer/parallax_layer as anything in C.parallax_layers)
		SET_COST("iterate layers")
		var/our_speed = parallax_layer.speed
		SET_COST("read speed var")
		var/change_x
		var/change_y
		var/old_x = parallax_layer.pixel_x
		var/old_y = parallax_layer.pixel_y
		SET_COST("create change vars")
		if(parallax_layer.absolute)
			SET_COST("check absolute")
			// We use change here so the typically large absolute objects (just lavaland for now) don't jitter so much
			change_x = (posobj.x - SSparallax.planet_x_offset) * our_speed + old_x
			SET_COST("abs calc delta x")
			change_y = (posobj.y - SSparallax.planet_y_offset) * our_speed + old_y
			SET_COST("abs calc delta y")
		else
			SET_COST("check absolute")
			change_x = offset_x * our_speed
			SET_COST("calc delta x")
			change_y = offset_y * our_speed
			SET_COST("calc delta y")

			// This is how we tile parralax sprites
			// It doesn't use change because we really don't want to animate this
			if(old_x - change_x > 240)
				SET_COST("tile check x > 240")
				parallax_layer.pixel_x -= 480
				SET_COST("tile offset x - 480")
			else if(old_x - change_x < -240)
				SET_COST("tile check x < -240")
				parallax_layer.pixel_x += 480
				SET_COST("tile offset x + 480")
			else
				SET_COST("tile check failed")
			if(old_y - change_y > 240)
				SET_COST("tile check y > 240")
				parallax_layer.pixel_y -= 480
				SET_COST("tile offset y - 480")
			else if(old_y - change_y < -240)
				SET_COST("tile check y < -240")
				parallax_layer.pixel_y += 480
				SET_COST("tile offset y + 480")
			else
				SET_COST("tile check failed")
		// Now that we have our offsets, let's do our positioning
		// We're going to use an animate to "glide" that last movement out, so it looks nicer
		// Don't do any animates if we're not actually moving enough distance yeah? thanks lad
		if(run_parralax && (largest_change * our_speed > 1))
			SET_COST("check run parallax")
			animate(parallax_layer, pixel_x = parallax_layer.pixel_x - change_x, pixel_y = parallax_layer.pixel_y - change_y, time = glide_rate)
			SET_COST("animate pixel offsets")
		else
			SET_COST("check run parallax")
			parallax_layer.pixel_x -= change_x
			SET_COST("offset pixel x")
			parallax_layer.pixel_y -= change_y
			SET_COST("offset pixel y")

	SET_COST("finish iterate layers")

/atom/movable/proc/update_parallax_contents()
	for(var/mob/client_mob as anything in client_mobs_in_contents)
		if(length(client_mob?.client?.parallax_layers) && client_mob.hud_used)
			client_mob.hud_used.update_parallax()

/mob/proc/update_parallax_teleport() //used for arrivals shuttle
	if(client?.eye && hud_used && length(client.parallax_layers))
		var/area/areaobj = get_area(client.eye)
		hud_used.set_parallax_movedir(areaobj.parallax_movedir, TRUE)

// Root object for parallax, all parallax layers are drawn onto this
INITIALIZE_IMMEDIATE(/atom/movable/screen/parallax_home)
/atom/movable/screen/parallax_home
	icon = null
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	screen_loc = "CENTER-7,CENTER-7"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

// We need parallax to always pass its args down into initialize, so we immediate init it
INITIALIZE_IMMEDIATE(/atom/movable/screen/parallax_layer)
/atom/movable/screen/parallax_layer
	icon = 'icons/effects/parallax.dmi'
	var/speed = 1
	var/offset_x = 0
	var/offset_y = 0
	var/absolute = FALSE
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	screen_loc = "CENTER-7,CENTER-7"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/parallax_layer/Initialize(mapload, datum/hud/hud_owner, template = FALSE)
	. = ..()
	// Parallax layers are independant of hud, they care about client
	// Not doing this will just create a bunch of hard deletes
	hud = null

	if(template)
		return

	var/client/boss = hud_owner?.mymob?.canon_client

	if(!boss) // If this typepath all starts to harddel your culprit is likely this
		return INITIALIZE_HINT_QDEL

	// I do not want to know bestie
	var/view = boss.view || world.view
	update_o(view)
	RegisterSignal(boss, COMSIG_VIEW_SET, PROC_REF(on_view_change))

/atom/movable/screen/parallax_layer/proc/on_view_change(datum/source, new_size)
	SIGNAL_HANDLER
	update_o(new_size)

/atom/movable/screen/parallax_layer/proc/update_o(view)
	if (!view)
		view = world.view

	var/static/parallax_scaler = world.icon_size / 480

	// Turn the view size into a grid of correctly scaled overlays
	var/list/viewscales = getviewsize(view)
	var/countx = CEILING((viewscales[1] / 2) * parallax_scaler, 1) + 1
	var/county = CEILING((viewscales[2] / 2) * parallax_scaler, 1) + 1
	var/list/new_overlays = new
	for(var/x in -countx to countx)
		for(var/y in -county to county)
			if(x == 0 && y == 0)
				continue
			var/mutable_appearance/texture_overlay = mutable_appearance(icon, icon_state)
			texture_overlay.pixel_x += 480 * x
			texture_overlay.pixel_y += 480 * y
			new_overlays += texture_overlay
	cut_overlays()
	add_overlay(new_overlays)

/atom/movable/screen/parallax_layer/layer_1
	icon_state = "layer1"
	speed = 0.6
	layer = 1

/atom/movable/screen/parallax_layer/layer_2
	icon_state = "layer2"
	speed = 1
	layer = 2

/atom/movable/screen/parallax_layer/layer_3
	icon_state = "layer3"
	speed = 1.4
	layer = 3

/atom/movable/screen/parallax_layer/planet
	icon_state = "planet"
	blend_mode = BLEND_OVERLAY
	absolute = TRUE //Status of seperation
	speed = 3
	layer = 30

/atom/movable/screen/parallax_layer/planet/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	var/client/boss = hud_owner?.mymob?.canon_client
	if(!boss)
		return
	var/static/list/connections = list(
		COMSIG_MOVABLE_Z_CHANGED = PROC_REF(on_z_change),
		COMSIG_MOB_LOGOUT = PROC_REF(on_mob_logout),
	)
	AddComponent(/datum/component/connect_mob_behalf, boss, connections)
	on_z_change(hud_owner?.mymob)

/atom/movable/screen/parallax_layer/planet/proc/on_mob_logout(mob/source)
	SIGNAL_HANDLER
	var/client/boss = source.canon_client
	on_z_change(boss.mob)

/atom/movable/screen/parallax_layer/planet/proc/on_z_change(mob/source)
	SIGNAL_HANDLER
	var/client/boss = source.client
	var/turf/posobj = get_turf(boss?.eye)
	if(!posobj)
		return
	SetInvisibility(is_station_level(posobj.z) ? INVISIBILITY_NONE : INVISIBILITY_ABSTRACT, id=type)

/atom/movable/screen/parallax_layer/planet/update_o()
	return //Shit won't move
