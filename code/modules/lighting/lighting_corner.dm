// Because we can control each corner of every lighting object.
// And corners get shared between multiple turfs (unless you're on the corners of the map, then 1 corner doesn't).
// For the record: these should never ever ever be deleted, even if the turf doesn't have dynamic lighting.

/atom/movable/lighting_corner
	name = ""
	anchored = TRUE
	icon = 'icons/effects/light_object_big.dmi'
	icon_state = "light_corner"
	plane = LIGHTING_PLANE
	blend_mode = BLEND_ADD
	color = "#000000" //we manually set color in init instead
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	invisibility = INVISIBILITY_LIGHTING
	vis_flags = VIS_HIDE

	var/list/datum/light_source/affecting // Light sources affecting us.

	var/real_x = 0
	var/real_y = 0
	var/real_z = 0

	var/turf/master_NE
	var/turf/master_SE
	var/turf/master_SW
	var/turf/master_NW
	var/turf/home_turf

	//"raw" color values, changed by update_lumcount()
	var/lum_r = 0
	var/lum_g = 0
	var/lum_b = 0

	//true color values, guaranteed to be between 0 and 1
	var/cache_r = LIGHTING_SOFT_THRESHOLD
	var/cache_g = LIGHTING_SOFT_THRESHOLD
	var/cache_b = LIGHTING_SOFT_THRESHOLD

	///the maximum of lum_r, lum_g, and lum_b. if this is > 1 then the three cached color values are divided by this
	var/largest_color_luminosity = 0

	///whether we are to be added to SSlighting's corners_queue list for an update
	var/needs_update = FALSE

// Takes as an argument the coords to use as the bottom left (south west) of our corner
/atom/movable/lighting_corner/New(loc, x, y, z)
	. = ..()

	src.real_x = x + 0.5
	src.real_y = y + 0.5
	src.real_z = z
	home_turf = loc
	pixel_w = (x - home_turf.x) * 32
	pixel_z = (y - home_turf.y) * 32
	//add_filter("Color Shift", 1, color_matrix_filter(list(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,1)))

	// Alright. We're gonna take a set of coords, and from them do a loop clockwise
	// To build out the turfs adjacent to us. This is pretty fast
	var/turf/process_next = locate(x, y, z)
	if(process_next)
		master_SW = process_next
		process_next.lighting_corner_NE = src
		// Now, we go north!
		process_next = get_step(process_next, NORTH)
	else
		// Yes this is slightly slower then having a guarenteeed turf, but there aren't many null turfs
		// So this is pretty damn fast
		process_next = locate(x, y + 1, z)

	// Ok, if we have a north turf, go there. otherwise, onto the next
	if(process_next)
		master_NW = process_next
		process_next.lighting_corner_SE = src
		// Now, TO THE EAST
		process_next = get_step(process_next, EAST)
	else
		process_next = locate(x + 1, y + 1, z)

	// Etc etc
	if(process_next)
		master_NE = process_next
		process_next.lighting_corner_SW = src
		// Now, TO THE SOUTH AGAIN (SE)
		process_next = get_step(process_next, SOUTH)
	else
		process_next = locate(x + 1, y, z)

	// anddd the last tile
	if(process_next)
		master_SE = process_next
		process_next.lighting_corner_NW = src


/atom/movable/lighting_corner/proc/self_destruct_if_idle()
	if (!LAZYLEN(affecting))
		qdel(src, force = TRUE)

/atom/movable/lighting_corner/proc/vis_update()
	for (var/datum/light_source/light_source as anything in affecting)
		light_source.vis_update()

/atom/movable/lighting_corner/proc/full_update()
	for (var/datum/light_source/light_source as anything in affecting)
		light_source.recalc_corner(src)

// God that was a mess, now to do the rest of the corner code! Hooray!
/atom/movable/lighting_corner/proc/update_lumcount(delta_r, delta_g, delta_b)

#ifdef VISUALIZE_LIGHT_UPDATES
	if (!SSlighting.allow_duped_values && !(delta_r || delta_g || delta_b)) // 0 is falsey ok
		return
#else
	if (!(delta_r || delta_g || delta_b)) // 0 is falsey ok
		return
#endif

	lum_r += delta_r
	lum_g += delta_g
	lum_b += delta_b

	if (!needs_update)
		needs_update = TRUE
		SSlighting.corners_queue += src

/atom/movable/lighting_corner/proc/update_objects()
	if (loc != home_turf)
		if (loc)
			var/turf/oldturf = get_turf(home_turf)
			var/turf/newturf = get_turf(loc)
			warning("A lighting corner realised it's loc had changed in update() ([home_turf]\[[home_turf ? home_turf.type : "null"]]([COORD(oldturf)]) -> [loc]\[[ loc ? loc.type : "null"]]([COORD(newturf)]))!")

		qdel(src, TRUE)
		return

#ifdef VISUALIZE_LIGHT_UPDATES
	for(var/turf/adjacent in list(master_NE, master_NW, master_SE, master_SW))
		adjacent.add_atom_colour(COLOR_BLUE_LIGHT, ADMIN_COLOUR_PRIORITY)
		animate(adjacent, 10, color = null)
		addtimer(CALLBACK(adjacent, TYPE_PROC_REF(/atom, remove_atom_colour), ADMIN_COLOUR_PRIORITY, COLOR_BLUE_LIGHT), 10, TIMER_UNIQUE|TIMER_OVERRIDE)
#endif

	// Cache these values ahead of time so 4 individual lighting objects don't all calculate them individually.
	var/lum_r = src.lum_r
	var/lum_g = src.lum_g
	var/lum_b = src.lum_b
	var/largest_color_luminosity = max(lum_r, lum_g, lum_b) // Scale it so one of them is the strongest lum, if it is above 1.
	. = 1 // factor
	if (largest_color_luminosity > 1)
		. = 1 / largest_color_luminosity

	var/old_r = cache_r
	var/old_g = cache_g
	var/old_b = cache_b

	#if LIGHTING_SOFT_THRESHOLD != 0
	if (largest_color_luminosity < LIGHTING_SOFT_THRESHOLD)
		. = 0 // 0 means soft lighting.

	cache_r = round(lum_r * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	cache_g = round(lum_g * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	cache_b = round(lum_b * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	#else
	cache_r = round(lum_r * ., LIGHTING_ROUND_VALUE)
	cache_g = round(lum_g * ., LIGHTING_ROUND_VALUE)
	cache_b = round(lum_b * ., LIGHTING_ROUND_VALUE)
	#endif

	src.largest_color_luminosity = round(largest_color_luminosity, LIGHTING_ROUND_VALUE)
#ifdef VISUALIZE_LIGHT_UPDATES
	if(!SSlighting.allow_duped_corners && old_r == cache_r && old_g == cache_g && old_b == cache_b)
		return
#else
	if(old_r == cache_r && old_g == cache_g && old_b == cache_b)
		return
#endif
	color = rgb(cache_r * 255, cache_g * 255, cache_b * 255)

	#if LIGHTING_SOFT_THRESHOLD != 0
	var/set_luminosity = largest_color_luminosity > LIGHTING_SOFT_THRESHOLD
	#else
	// Because of floating points™?, it won't even be a flat 0.
	// This number is mostly arbitrary.
	var/set_luminosity = largest_color_luminosity > 1e-6
	#endif
	if(set_luminosity)
		master_NE?.luminosity = 1
		master_SE?.luminosity = 1
		master_SW?.luminosity = 1
		master_NW?.luminosity = 1
	else
		master_NE?.calc_lumin()
		master_SE?.calc_lumin()
		master_SW?.calc_lumin()
		master_NW?.calc_lumin()

	self_destruct_if_idle()

/atom/movable/lighting_corner/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE


	for (var/datum/light_source/light_source as anything in affecting)
		LAZYREMOVE(light_source.effect_str, src)
	affecting = null

	if (master_NE)
		master_NE.lighting_corner_SW = null
		master_NE.lighting_corners_initialised = FALSE
	if (master_SE)
		master_SE.lighting_corner_NW = null
		master_SE.lighting_corners_initialised = FALSE
	if (master_SW)
		master_SW.lighting_corner_NE = null
		master_SW.lighting_corners_initialised = FALSE
	if (master_NW)
		master_NW.lighting_corner_SE = null
		master_NW.lighting_corners_initialised = FALSE
	if (needs_update)
		SSlighting.corners_queue -= src

	if (loc != home_turf)
		var/turf/oldturf = get_turf(home_turf)
		var/turf/newturf = get_turf(loc)
		stack_trace("A lighting corner was qdeleted with a different loc then it is suppose to have ([COORD(oldturf)] -> [COORD(newturf)])")
	if (isturf(home_turf))
		home_turf.luminosity = 1
	home_turf = null
	return ..()

// Variety of overrides so the overlays don't get affected by weird things.

/atom/movable/lighting_corner/ex_act(severity)
	return FALSE

/atom/movable/lighting_corner/singularity_act()
	return

/atom/movable/lighting_corner/singularity_pull()
	return

/atom/movable/lighting_corner/blob_act()
	return

/atom/movable/lighting_corner/on_changed_z_level(turf/old_turf, turf/new_turf, same_z_layer, notify_contents = TRUE)
	SHOULD_CALL_PARENT(FALSE)
	return

/atom/movable/lighting_corner/wash(clean_types)
	SHOULD_CALL_PARENT(FALSE) // lighting objects are dirty, confirmed
	return

// Override here to prevent things accidentally moving around overlays.
/atom/movable/lighting_corner/forceMove(atom/destination, no_tp = FALSE, harderforce = FALSE)
	if(harderforce)
		return ..()

/// Debug proc to aid in understanding how corners work
/atom/movable/lighting_corner/proc/display(max_lum)
	if(QDELETED(src))
		return

	var/turf/draw_to = master_SW || master_NE || master_SE || master_NW
	var/mutable_appearance/display = mutable_appearance('icons/turf/debug.dmi', "corner_color", LIGHT_DEBUG_LAYER, draw_to, BALLOON_CHAT_PLANE)
	if(x > draw_to.x)
		display.pixel_x = 16
	else
		display.pixel_x = -16
	if(y > draw_to.y)
		display.pixel_y = 16
	else
		display.pixel_y = -16

	display.color = display.color = rgb(cache_r * 255, cache_g * 255, cache_b * 255)

	draw_to.add_overlay(display)

/// Makes all lighting corners visible, debug to aid in understanding
/proc/display_corners()
	var/list/corners = list()
	var/max_lum = 0
	for(var/atom/movable/lighting_corner/corner in world) // I am so sorry
		corners += corner
		max_lum = max(max_lum, corner.largest_color_luminosity)


	for(var/atom/movable/lighting_corner/corner as anything in corners)
		corner.display(max_lum)
