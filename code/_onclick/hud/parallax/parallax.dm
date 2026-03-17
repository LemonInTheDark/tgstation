/// Decides if parallax should be rendered or not, and sets things up accordingly
/datum/hud/proc/check_parallax()
	var/client/displaying_client = mymob.client
	if(isnull(displaying_client.parallax_rock))
		displaying_client.parallax_rock = new(null, null, displaying_client)

	/// Applies our preferences to our existing display
	apply_parallax_pref()
	var/atom/movable/screen/parallax_home/rock = displaying_client?.parallax_rock

	// Because other parts of the code can just REMOVE US FROM THE SCREEN for no reason as a joke
	if (rock.displaying_layers)
		ADD_TRAIT(src, TRAIT_PARALLAX_DISPLAYED, TRAIT_GENERIC)
		displaying_client.screen |= rock
	else
		REMOVE_TRAIT(src, TRAIT_PARALLAX_DISPLAYED, TRAIT_GENERIC)
		displaying_client.screen -= rock

/datum/hud/proc/apply_parallax_pref()
	var/turf/screen_location = get_turf(mymob)
	var/client/displaying_client = mymob.client
	var/atom/movable/screen/parallax_home/rock = displaying_client.parallax_rock

	if(SSmapping.level_trait(screen_location?.z, ZTRAIT_NOPARALLAX))
		rock.set_layer_settings(layers_to_draw = 0, draw_old_space = FALSE, animate_parallax = FALSE, allow_objects = FALSE)
		return

	if (SSlag_switch.measures[DISABLE_PARALLAX] && !HAS_TRAIT(mymob, TRAIT_BYPASS_MEASURES))
		rock.set_layer_settings(layers_to_draw = 0, draw_old_space = FALSE, animate_parallax = FALSE, allow_objects = FALSE)
		return

	// Default to HIGH
	var/parallax_selection = displaying_client?.prefs.read_preference(/datum/preference/choiced/parallax) || PARALLAX_HIGH

	switch(parallax_selection)
		if (PARALLAX_INSANE)
			rock.set_layer_settings(layers_to_draw = 5, draw_old_space = FALSE, animate_parallax = TRUE, allow_objects = TRUE)
			return

		if(PARALLAX_HIGH)
			rock.set_layer_settings(layers_to_draw = 4, draw_old_space = FALSE, animate_parallax = TRUE, allow_objects = TRUE)
			return

		if (PARALLAX_MED)
			rock.set_layer_settings(layers_to_draw = 3, draw_old_space = FALSE, animate_parallax = TRUE, allow_objects = TRUE)
			return

		if (PARALLAX_LOW)
			rock.set_layer_settings(layers_to_draw = 1, draw_old_space = FALSE, animate_parallax = FALSE, allow_objects = FALSE)
			return

		if (PARALLAX_BOOMER)
			rock.set_layer_settings(layers_to_draw = 0, draw_old_space = TRUE, animate_parallax = TRUE, allow_objects = FALSE)
			return

		if (PARALLAX_DISABLE)
			rock.set_layer_settings(layers_to_draw = 0, draw_old_space = FALSE, animate_parallax = FALSE, allow_objects = FALSE)
			return

/datum/hud/proc/update_parallax_pref()
	if(!mymob.client)
		return
	check_parallax()
	update_parallax()

// This sets which way the current shuttle is moving (returns true if the shuttle has stopped moving so the caller can append their animation)
/datum/hud/proc/set_parallax_movedir(new_parallax_movedir = NONE, skip_windups)
	. = FALSE
	var/client/displaying_client = mymob.client
	if(new_parallax_movedir == displaying_client.parallax_movedir)
		return

	var/animation_dir = new_parallax_movedir || displaying_client.parallax_movedir
	var/matrix/new_transform
	switch(animation_dir)
		if(NORTH)
			new_transform = matrix(1, 0, 0, 0, 1, 480)
		if(SOUTH)
			new_transform = matrix(1, 0, 0, 0, 1,-480)
		if(EAST)
			new_transform = matrix(1, 0, 480, 0, 1, 0)
		if(WEST)
			new_transform = matrix(1, 0,-480, 0, 1, 0)

	var/longest_timer = 0
	for(var/key in displaying_client.parallax_animate_timers)
		deltimer(displaying_client.parallax_animate_timers[key])
	displaying_client.parallax_animate_timers = list()
	for(var/atom/movable/screen/parallax_layer/layer as anything in displaying_client.parallax_rock.parallax_layers)
		var/scaled_time = PARALLAX_LOOP_TIME / layer.speed
		if(new_parallax_movedir == NONE) // If we're stopping, we need to stop on the same dime, yeah?
			scaled_time = PARALLAX_LOOP_TIME
		longest_timer = max(longest_timer, scaled_time)

		if(skip_windups)
			update_parallax_motionblur(displaying_client, layer, new_parallax_movedir, new_transform)
			continue

		layer.transform = new_transform
		animate(layer, transform = matrix(), time = scaled_time, easing = QUAD_EASING | (new_parallax_movedir ? EASE_IN : EASE_OUT))
		if (new_parallax_movedir == NONE)
			continue
		//queue up another animate so lag doesn't create a shutter
		animate(transform = new_transform, time = 0)
		animate(transform = matrix(), time = scaled_time / 2)
		displaying_client.parallax_animate_timers[layer] = addtimer(CALLBACK(src, PROC_REF(update_parallax_motionblur), displaying_client, layer, new_parallax_movedir, new_transform), scaled_time, TIMER_CLIENT_TIME|TIMER_STOPPABLE)

	displaying_client.dont_animate_parallax = world.time + min(longest_timer, PARALLAX_LOOP_TIME)
	displaying_client.parallax_movedir = new_parallax_movedir

/datum/hud/proc/update_parallax_motionblur(client/displaying_client, atom/movable/screen/parallax_layer/layer, new_parallax_movedir, matrix/new_transform)
	if(!displaying_client)
		return
	displaying_client.parallax_animate_timers -= layer

	// If we are moving in a direction, we used the QUAD_EASING function with EASE_IN
	// This means our position function is x^2. This is always LESS then the linear we're using here
	// But if we just used the same time delay, our rate of change would mismatch. f'(1) = 2x for quad easing, rather then the 1 we get for linear
	// (This is because of how derivatives work right?)
	// Because of this, while our actual rate of change from before was PARALLAX_LOOP_TIME, our perceived rate of change was PARALLAX_LOOP_TIME / 2 (lower == faster).
	// Let's account for that here
	var/scaled_time = (PARALLAX_LOOP_TIME / layer.speed) / 2
	animate(layer, transform = new_transform, time = 0, loop = -1, flags = ANIMATION_END_NOW)
	animate(transform = matrix(), time = scaled_time)

/datum/hud/proc/update_parallax()
	var/client/displaying_client = mymob.client
	var/turf/posobj = get_turf(displaying_client.eye)
	if(!posobj)
		return

	var/area/areaobj = posobj.loc
	// Update the movement direction of the parallax if necessary (for shuttles)
	set_parallax_movedir(areaobj.parallax_movedir, FALSE, mymob)

	if(!displaying_client.previous_turf || (displaying_client.previous_turf.z != posobj.z))
		displaying_client.previous_turf = posobj

	//Doing it this way prevents parallax layers from "jumping" when you change Z-Levels.
	var/offset_x = posobj.x - displaying_client.previous_turf.x
	var/offset_y = posobj.y - displaying_client.previous_turf.y

	var/glide_rate = round(ICON_SIZE_ALL / mymob.glide_size * world.tick_lag, world.tick_lag)
	displaying_client.previous_turf = posobj

	var/largest_change = max(abs(offset_x), abs(offset_y))
	var/max_allowed_dist = (glide_rate / world.tick_lag) + 1
	var/atom/movable/screen/parallax_home/rock = displaying_client.parallax_rock
	rock.update_parallax_position(posobj.x, posobj.y, posobj.z)

	// If we aren't already moving/don't allow parallax, have made some movement, and that movement was smaller then our "glide" size, animate
	var/run_parralax = (rock.animate_parallax && glide_rate && !areaobj.parallax_movedir && displaying_client.dont_animate_parallax <= world.time && largest_change <= max_allowed_dist)

	for(var/atom/movable/screen/parallax_layer/parallax_layer as anything in rock.parallax_layers)
		var/our_speed = parallax_layer.speed
		var/change_x
		var/change_y
		var/old_x = parallax_layer.offset_x
		var/old_y = parallax_layer.offset_y
		if(parallax_layer.absolute)
			// We use change here so the typically large absolute objects (just lavaland for now) don't jitter so much
			change_x = (posobj.x - SSparallax.planet_x_offset) * our_speed + old_x
			change_y = (posobj.y - SSparallax.planet_y_offset) * our_speed + old_y
		else
			change_x = offset_x * our_speed
			change_y = offset_y * our_speed

			// This is how we tile parralax sprites
			// It doesn't use change because we really don't want to animate this
			if(old_x - change_x > 240)
				parallax_layer.offset_x -= 480
				parallax_layer.pixel_w = parallax_layer.offset_x
				parallax_layer.update_visuals()
			else if(old_x - change_x < -240)
				parallax_layer.offset_x += 480
				parallax_layer.pixel_w = parallax_layer.offset_x
				parallax_layer.update_visuals()
			if(old_y - change_y > 240)
				parallax_layer.offset_y -= 480
				parallax_layer.pixel_z = parallax_layer.offset_y
				parallax_layer.update_visuals()
			else if(old_y - change_y < -240)
				parallax_layer.offset_y += 480
				parallax_layer.pixel_z = parallax_layer.offset_y
				parallax_layer.update_visuals()

		parallax_layer.offset_x -= change_x
		parallax_layer.offset_y -= change_y
		// Now that we have our offsets, let's do our positioning
		// We're going to use an animate to "glide" that last movement out, so it looks nicer
		// Don't do any animates if we're not actually moving enough distance yeah? thanks lad
		if(run_parralax && (largest_change * our_speed > 1))
			animate(parallax_layer, pixel_w = round(parallax_layer.offset_x, 1), pixel_z = round(parallax_layer.offset_y, 1), time = glide_rate)
		else
			parallax_layer.pixel_w = round(parallax_layer.offset_x, 1)
			parallax_layer.pixel_z = round(parallax_layer.offset_y, 1)

/atom/movable/proc/update_parallax_contents()
	for(var/mob/client_mob as anything in client_mobs_in_contents)
		if(client_mob?.client?.parallax_rock?.displaying_layers && client_mob.hud_used)
			client_mob.hud_used.update_parallax()

/mob/proc/update_parallax_teleport() //used for arrivals shuttle
	if(client?.eye && hud_used && client?.parallax_rock?.displaying_layers)
		var/area/areaobj = get_area(client.eye)
		hud_used.set_parallax_movedir(areaobj.parallax_movedir, TRUE)

// Root object for parallax, all parallax layers are drawn onto this and it manages them
INITIALIZE_IMMEDIATE(/atom/movable/screen/parallax_home)
/atom/movable/screen/parallax_home
	icon = null
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	screen_loc = "CENTER-7,CENTER-7"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Layers we are currently displaying
	var/list/atom/movable/screen/parallax_layer/parallax_layers = list()
	/// Pallet of layers we CAN display if we choose to, depending on our client's prefs
	/// ensures quick removal/reinsertion doesn't cause cycling qdels
	var/list/atom/movable/screen/parallax_layer/parallax_layers_cached = list()
	/// How many normal space layers we want to draw, in increasing order of "depth"
	var/layers_to_draw = 0
	/// If we want to draw the old space layer
	var/draw_old_space = FALSE
	/// Are we currently displaying any layers?
	var/displaying_layers = FALSE
	/// Are we animating parallax?
	var/animate_parallax = FALSE
	/// Do we currently allow parallax objects to render?
	var/allow_objects = FALSE
	/// List of parallax "[speeds]" that are requested for rendering mapped to a list of the visuals requesting them
	var/list/list/obj/effect/abstract/parallax_display/requested_speeds = list()
	/// List of parallax objects that are currently attempting to render near us mapped to our effect interceptor for their appearance
	var/list/datum/parallax_object/floating_objects_to_display = list()
	/// List of parallax cells we can currently see
	var/list/datum/parallax_cell/cells_in_sight = list()
	/// Last x position of the center of our eye
	var/x_coord = 0
	/// Last y position of the center of our eye
	var/y_coord = 0
	/// Last z position of the center of our eye
	var/z_coord = 0
	/// X coord of the lowest parallax cell we can see
	var/parallax_lower_x = 0
	/// Y coord of the lowest parallax cell we can see
	var/parallax_lower_y = 0
	/// X coord of the highest parallax cell we can see
	var/parallax_upper_x = 0
	/// Y coord of the highest parallax cell we can see
	var/parallax_upper_y = 0
	/// The client that owns us
	var/client/owner
	/// The current view of our client, if any (world.view by default otherwise)
	var/working_view

/atom/movable/screen/parallax_home/Initialize(mapload, datum/hud/hud_owner, client/owner)
	. = ..()
	src.owner = owner
	working_view = owner?.view
	if(isnull(working_view))
		working_view = world.view
	RegisterSignal(owner, COMSIG_VIEW_SET, PROC_REF(on_view_change))

/atom/movable/screen/parallax_home/Destroy()
	clear_layers()
	owner = null
	for(var/datum/parallax_object/object as anything in floating_objects_to_display)
		kill_object(object)
	return ..()

/atom/movable/screen/parallax_home/proc/on_view_change(datum/source, new_size)
	SIGNAL_HANDLER
	working_view = new_size
	for(var/atom/movable/screen/parallax_layer/displayed as anything in parallax_layers_cached)
		displayed.update_appearance()

/atom/movable/screen/parallax_home/proc/display_layers()
	if(displaying_layers || length(parallax_layers_cached) == 0)
		return
	parallax_layers = parallax_layers_cached
	vis_contents = parallax_layers_cached
	displaying_layers = TRUE

/atom/movable/screen/parallax_home/proc/hide_layers()
	if(!displaying_layers)
		return
	parallax_layers = list()
	vis_contents = list()
	displaying_layers = FALSE

/atom/movable/screen/parallax_home/proc/set_layer_settings(layers_to_draw, draw_old_space, animate_parallax, allow_objects)
	src.animate_parallax = animate_parallax
	if(src.layers_to_draw == layers_to_draw && src.draw_old_space == draw_old_space && src.allow_objects == allow_objects)
		return
	if(src.allow_objects != allow_objects)
		src.allow_objects = allow_objects
		rebuild_objects()
	src.layers_to_draw = layers_to_draw
	src.draw_old_space = draw_old_space
	regenerate_layers()

/// Updates "things that move"
/atom/movable/screen/parallax_home/proc/update_parallax_position(x_coord, y_coord, z_coord)
	src.x_coord = x_coord
	src.y_coord = y_coord
	src.z_coord = z_coord
	// Slower parallaxes care about things further out, because they can cover far more ground and still be in view
	update_parallax_bounds(x_coord - PARALLAX_RANGE, y_coord - PARALLAX_RANGE, x_coord + PARALLAX_RANGE, y_coord + PARALLAX_RANGE, z_coord)

/// Updates the cells we're in, allowing us to discard/find new objects to render
/atom/movable/screen/parallax_home/proc/update_parallax_bounds(x_lower, y_lower, x_upper, y_upper, cell_z)
	var/cell_x_lower = PARALLAX_CELL(x_lower)
	var/cell_y_lower = PARALLAX_CELL(y_lower)
	var/cell_x_upper = PARALLAX_CELL(x_upper)
	var/cell_y_upper = PARALLAX_CELL(y_upper)
	if(parallax_lower_x == cell_x_lower && parallax_lower_y == cell_y_lower && parallax_upper_x == cell_x_upper && parallax_upper_y == cell_y_upper && z_coord == cell_z)
		return

	var/list/new_cells = SSparallax.get_cells_by_bound(cell_x_lower, cell_y_lower, cell_x_upper, cell_y_upper, cell_z)
	parallax_lower_x = cell_x_lower
	parallax_lower_y = cell_y_lower
	parallax_upper_x = cell_x_upper
	parallax_upper_y = cell_y_upper
	z_coord = cell_z

	// I'll be here in sunshine or in shadow
	for(var/datum/parallax_cell/new_cell in new_cells - cells_in_sight)
		RegisterSignal(new_cell, COMSIG_PARALLAX_OBJECT_ENTERED, PROC_REF(object_entered))
		RegisterSignal(new_cell, COMSIG_PARALLAX_OBJECT_LEFT, PROC_REF(object_left))
		for(var/datum/parallax_object/new_guy in new_cell.members)
			place_object(new_guy)

	for(var/datum/parallax_cell/lost_cell in cells_in_sight - new_cells)
		UnregisterSignal(lost_cell, list(COMSIG_PARALLAX_OBJECT_ENTERED, COMSIG_PARALLAX_OBJECT_LEFT))
		for(var/datum/parallax_object/old_friend in lost_cell.members)
			remove_object(old_friend)

	cells_in_sight = new_cells

/atom/movable/screen/parallax_home/proc/object_entered(datum/source, datum/parallax_object/entered)
	SIGNAL_HANDLER
	place_object(entered)

/atom/movable/screen/parallax_home/proc/object_left(datum/source, datum/parallax_object/left)
	SIGNAL_HANDLER
	remove_object(left)

/obj/effect/abstract/parallax_display
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	appearance_flags = parent_type::appearance_flags | KEEP_APART

	// For debug purposes
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// The parallax layer we are currently displayed on, if any
	var/atom/movable/screen/parallax_layer/displaying_on
	/// Our parent parallax object, what we're derriving our visuals from
	var/datum/parallax_object/parent
	/// How many cell's worth of objects this is covering for
	var/object_count = 0

/obj/effect/abstract/parallax_object_holder

/obj/effect/abstract/parallax_display/New(loc, datum/parallax_object/parent)
	. = ..()
	src.parent = parent
	render_source = parent.visuals.render_target
	vis_contents += parent.visuals
	RegisterSignal(parent, COMSIG_PARALLAX_PLACED, PROC_REF(placed))
	RegisterSignal(parent, COMSIG_PARALLAX_MOVED, PROC_REF(moved))

/obj/effect/abstract/parallax_display/Destroy(force)
	var/atom/movable/screen/parallax_home/root = displaying_on.root
	root.kill_object(parent)
	hide()
	parent = null
	return ..()

/obj/effect/abstract/parallax_display/proc/placed(datum/source)
	SIGNAL_HANDLER
	update_position()

/// TODO: This should have some sort of like, animation attached, work it out later
/obj/effect/abstract/parallax_display/proc/moved(datum/source, animation_rate)
	SIGNAL_HANDLER
	var/old_x = pixel_x
	var/old_y = pixel_y
	update_position()
	// gonna do it old style
	if(max(abs(pixel_x - old_x), abs(pixel_y - old_y)) > 1)
		var/matrix/old_transform = transform
		transform = transform.Translate(old_x - pixel_x, old_y - pixel_y)
		animate(src, transform = old_transform, flags = ANIMATION_PARALLEL, time = animation_rate)


/obj/effect/abstract/parallax_display/proc/update_position()
	// We want to render at our world position + tiles_displayed * speed
	// The transform sets this up fine for us. The only problem is pinning ourselves to the world position when we are first placed
	// So as soon as we load, we need to set our pixel offset such that we draw ON the world position when tiles_displased = 0
	// If we are drawn when say, there's 16 tiles between our world position and the center of the view, the

	// 7 from the amount subtracted from the center
	// We take the distance between our center and target in visual pixels, scale it down using speed, and then subtract out physical offsets
	// (So the 7 turfs of physical offset from the centering of parallax, and the default offset involved when it was created)
	var/atom/movable/screen/parallax_home/root = displaying_on.root
	pixel_x = (parent.visual_x - root.x_coord * ICON_SIZE_X) * displaying_on.speed / ICON_SIZE_X + 7 * ICON_SIZE_X - displaying_on.offset_x
	pixel_y = (parent.visual_y - root.y_coord * ICON_SIZE_Y) * displaying_on.speed / ICON_SIZE_Y + 7 * ICON_SIZE_Y - displaying_on.offset_y
	message_admins("Testing [pixel_x] [pixel_y]")

/obj/effect/abstract/parallax_display/proc/hide()
	if(isnull(displaying_on))
		return
	displaying_on.hide_visual(src)

/// Places a parallax object near us, meaning we have to care about it/think about if it needs to be drawn or not
/atom/movable/screen/parallax_home/proc/place_object(datum/parallax_object/danny_boy)
	var/obj/effect/abstract/parallax_display/display = floating_objects_to_display[danny_boy]
	if(!allow_objects || display)
		display.object_count += 1
		return
	// But come ye back when summer's in the meadow, when the valley's hushed and white with snow
	var/obj/effect/abstract/parallax_display/display = new(src, danny_boy)
	floating_objects_to_display[danny_boy] = display
	display.object_count += 1

	RegisterSignal(danny_boy, COMSIG_PARALLAX_SET_SPEED, PROC_REF(object_changed_speed))
	requested_speeds["[danny_boy.speed]"] += list(display)
	if(length(requested_speeds["[danny_boy.speed]"]) == 1)
		update_speed_layers()
		return

	var/atom/movable/screen/parallax_layer/display_layer = get_layer_by_speed(danny_boy.speed)
	display_layer.display_visual(display)

/// Removes a parallax object we were once aware of from our awareness
/atom/movable/screen/parallax_home/proc/remove_object(datum/parallax_object/danny_boy)
	// Tis you who must go, and I must die...
	var/obj/effect/abstract/parallax_display/display = floating_objects_to_display[danny_boy]
	display.object_count -= 1
	if(display.object_count > 0)
		return
	kill_object(danny_boy)

/atom/movable/screen/parallax_home/proc/kill_object(datum/parallax_object/danny_boy)
	var/obj/effect/abstract/parallax_display/display = floating_objects_to_display[danny_boy]
	floating_objects_to_display -= danny_boy
	UnregisterSignal(danny_boy, list(COMSIG_PARALLAX_SET_SPEED))
	requested_speeds["[danny_boy.speed]"] -= display
	if(!QDELETED(display))
		qdel(display)
	if(!length(requested_speeds["[danny_boy.speed]"]))
		requested_speeds -= "[danny_boy.speed]"
		update_speed_layers()

/atom/movable/screen/parallax_home/proc/object_changed_speed(datum/parallax_object/source, old_speed, new_speed)
	SIGNAL_HANDLER
	var/update_required = FALSE
	var/obj/effect/abstract/parallax_display/display = floating_objects_to_display[source]
	display.hide()
	requested_speeds["[new_speed]"] += list(display)
	if(length(requested_speeds["[new_speed]"]) == 1)
		update_required = TRUE
	if(length(requested_speeds["[old_speed]"]))
		requested_speeds["[old_speed]"] -= display
	if(!length(requested_speeds["[old_speed]"]))
		requested_speeds -= "[old_speed]"
		update_required = TRUE
	if(update_required)
		update_speed_layers()
		return // Will display us all on its own

	var/atom/movable/screen/parallax_layer/display_layer = get_layer_by_speed(source.speed)
	display_layer.display_visual(display)

/// Clear all our parallax objects, then fetch all the ones we care about from the cells in range
/atom/movable/screen/parallax_home/proc/rebuild_objects()
	if(allow_objects)
		for(var/datum/parallax_cell/known_factor in cells_in_sight)
			for(var/datum/parallax_object/aquantience in known_factor.members)
				place_object(aquantience)
	else
		for(var/datum/parallax_cell/known_factor in cells_in_sight)
			for(var/datum/parallax_object/hated_enemy in known_factor.members)
				remove_object(hated_enemy)

/atom/movable/screen/parallax_home/proc/get_layer_by_speed(speed)
	for(var/atom/movable/screen/parallax_layer/layer as anything in parallax_layers_cached)
		if(layer.speed == speed)
			return layer
	return null

/atom/movable/screen/parallax_home/proc/generate_space_layer(index)
	switch(index)
		if(1)
			return new /atom/movable/screen/parallax_layer/layer_1(null, null, src)
		if(2)
			return new /atom/movable/screen/parallax_layer/layer_2(null, null, src)
		if(3)
			return new /atom/movable/screen/parallax_layer/planet(null, null, src)
		if(4)
			if(SSparallax.random_layer)
				return new SSparallax.random_layer.type(null, null, src, FALSE, SSparallax.random_layer)
			else
				return new /atom/movable/screen/parallax_layer/layer_3(null, null, src)
		if(5)
			if(SSparallax.random_layer)
				return new /atom/movable/screen/parallax_layer/layer_3(null, null, src)

/atom/movable/screen/parallax_home/proc/update_speed_layers()
	hide_layers()
	build_speed_layers()
	display_layers()

/atom/movable/screen/parallax_home/proc/build_speed_layers()
	for(var/requested_speed in requested_speeds)
		var/speed = text2num(requested_speed)
		var/atom/movable/screen/parallax_layer/holder = get_layer_by_speed(speed)
		if(!holder)
			var/atom/movable/screen/parallax_layer/empty/empty_holder = new(null, null, src)
			empty_holder.set_speed(speed)
			parallax_layers_cached += empty_holder
			holder = empty_holder
		for(var/obj/effect/abstract/parallax_display/visual as anything in requested_speeds[requested_speed])
			if(visual.displaying_on == holder)
				continue
			holder.display_visual(visual)

	// Very intentional typecast here
	for(var/atom/movable/screen/parallax_layer/empty/empty_display in parallax_layers_cached)
		if(!length(empty_display.displaying_visuals))
			qdel(empty_display)

/atom/movable/screen/parallax_home/proc/regenerate_layers()
	clear_layers()
	if(layers_to_draw == 0 && !draw_old_space)
		return

	parallax_layers_cached = list()
	for(var/space_layer in 1 to layers_to_draw)
		parallax_layers_cached += generate_space_layer(space_layer)

	if(draw_old_space)
		parallax_layers_cached += new /atom/movable/screen/parallax_layer/old(null, null, src)

	build_speed_layers()
	display_layers()

/atom/movable/screen/parallax_home/proc/clear_layers()
	hide_layers()
	QDEL_LIST(parallax_layers_cached)

// We need parallax to always pass its args down into initialize, so we immediate init it
INITIALIZE_IMMEDIATE(/atom/movable/screen/parallax_layer)
/atom/movable/screen/parallax_layer
	icon = 'icons/effects/parallax.dmi'
	var/speed = 1
	var/offset_x = 0
	var/offset_y = 0
	var/absolute = FALSE
	appearance_flags = APPEARANCE_UI | KEEP_TOGETHER
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Root datum we're currently being displayed on, if any
	var/atom/movable/screen/parallax_home/root
	/// List of parallax visuals we're currently displaying
	var/list/obj/effect/abstract/parallax_display/displaying_visuals = list()
	/// Do we draw multiple tiles of ourselves?
	var/draw_tiles = TRUE

/atom/movable/screen/parallax_layer/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/root, template = FALSE)
	. = ..()
	// Parallax layers are independent of hud, they care about client
	// Not doing this will just create a bunch of hard deletes
	set_new_hud(hud_owner = null)

	// Makes organizing these things easier
	layer = speed
	if(template)
		return

	src.root = root
	if(!root) // If this typepath all starts to harddel your culprit is likely this
		return INITIALIZE_HINT_QDEL
	// Regen overlays
	update_appearance()
	var/client/displaying_client = root.owner
	set_default_position(get_turf(displaying_client.eye))

/atom/movable/screen/parallax_layer/Destroy()
	for(var/obj/effect/abstract/parallax_display/visual as anything in displaying_visuals)
		visual.hide()
	root.parallax_layers -= src
	root.parallax_layers_cached -= src
	root = null
	return ..()

/// For kids who want to set a more complex default position for themselves
/atom/movable/screen/parallax_layer/proc/set_default_position()
	return

/atom/movable/screen/parallax_layer/update_overlays()
	. = ..()
	if(!draw_tiles)
		return

	var/overlay_view = root?.working_view
	if (!overlay_view)
		overlay_view = world.view
	var/pixel_grid_size = ICON_SIZE_ALL * 15
	var/parallax_scaler = ICON_SIZE_ALL / pixel_grid_size

	// Turn the view size into a grid of correctly scaled overlays
	var/list/viewscales = getviewsize(overlay_view)
	// This could be half the size but we need to provide space for parallax movement on mob movement, and movement on scroll from shuttles, so like this instead
	var/countx = (CEILING((viewscales[1] / 2) * parallax_scaler, 1) + 1)
	var/county = (CEILING((viewscales[2] / 2) * parallax_scaler, 1) + 1)
	for(var/x in -countx to countx)
		for(var/y in -county to county)
			if(x == 0 && y == 0)
				continue
			var/mutable_appearance/texture_overlay = tileable_appearance()
			texture_overlay.pixel_w += pixel_grid_size * x
			texture_overlay.pixel_z += pixel_grid_size * y
			. += texture_overlay

/atom/movable/screen/parallax_layer/proc/tileable_appearance()
	return mutable_appearance(icon, icon_state)

/atom/movable/screen/parallax_layer/proc/display_visual(obj/effect/abstract/parallax_display/visual)
	if(visual.displaying_on)
		visual.hide()
	visual.displaying_on = src
	displaying_visuals += visual
	vis_contents += visual
	visual.update_position()

/atom/movable/screen/parallax_layer/proc/hide_visual(obj/effect/abstract/parallax_display/visual)
	displaying_visuals -= visual
	vis_contents -= visual
	visual.displaying_on = null

/atom/movable/screen/parallax_layer/proc/update_visuals()
	for(var/obj/effect/abstract/parallax_display/visual as anything in displaying_visuals)
		visual.update_position()

/atom/movable/screen/parallax_layer/empty
	draw_tiles = FALSE
	icon_state = "empty"

/atom/movable/screen/parallax_layer/empty/proc/set_speed(new_speed)
	speed = new_speed
	layer = new_speed

/atom/movable/screen/parallax_layer/layer_1
	icon_state = "layer1"
	speed = 0.6

/atom/movable/screen/parallax_layer/layer_2
	icon_state = "layer2"
	speed = 1

/atom/movable/screen/parallax_layer/layer_3
	icon_state = "layer3"
	speed = 1.4

/atom/movable/screen/parallax_layer/old
	icon = null
	icon_state = null // dog there's gonna be so many overlays...
	speed = 0.6

/atom/movable/screen/parallax_layer/old/tileable_appearance()
	var/mutable_appearance/copy = mutable_appearance(null, "")
	// We have to use render targets to draw one of these flat and reuse it for this because FOR SOME REASON
	// 16 (tile count) * (14 (animated state count) * 4 (frame count) + 1 (1 is not animated)) 480x480 states
	// is TOO MUCH for the client. Whatever, see if I care.
	copy.render_source = "*old_space_parallax"
	return copy

/atom/movable/screen/parallax_layer/old/update_overlays()
	. = ..()
	var/mutable_appearance/relayed_overlay = mutable_appearance('icons/effects/old_parallax.dmi', "1", appearance_flags = RESET_TRANSFORM|PIXEL_SCALE|KEEP_TOGETHER|KEEP_APART)
	var/list/old_states = list("19", "21", "23", "24", "26", "29", "30", "31", "34", "35", "36", "37", "43", "46")
	var/list/holder_overlays = list()
	for(var/state in old_states)
		holder_overlays += mutable_appearance('icons/effects/old_parallax.dmi', state)
	relayed_overlay.overlays = holder_overlays
	relayed_overlay.render_target = "*old_space_parallax"
	// Renders the like, "input" appearance we draw to everything else
	. += relayed_overlay
	// The 0,0 appearance, can't reuse relayed_overlay for this because otherwise transforms would stack
	. += tileable_appearance()

/atom/movable/screen/parallax_layer/planet
	icon_state = "planet"
	blend_mode = BLEND_OVERLAY
	absolute = TRUE //Status of separation
	draw_tiles = FALSE
	speed = 3

/atom/movable/screen/parallax_layer/planet/Initialize(mapload, datum/hud/hud_owner, atom/movable/screen/parallax_home/root)
	. = ..()
	var/client/owner = root.owner
	if(!owner)
		return
	var/static/list/connections = list(
		COMSIG_MOVABLE_Z_CHANGED = PROC_REF(on_z_change),
		COMSIG_MOB_LOGOUT = PROC_REF(on_mob_logout),
	)
	AddComponent(/datum/component/connect_mob_behalf, owner, connections)
	on_z_change(owner.mob)

/// For kids who want to set a more complex default position for themselves
/atom/movable/screen/parallax_layer/planet/set_default_position(atom/movable/posobj)
	offset_x = -(posobj.x - SSparallax.planet_x_offset) * speed
	offset_y = -(posobj.y - SSparallax.planet_y_offset) * speed
	pixel_w = round(offset_x, 1)
	pixel_z = round(offset_y, 1)

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
