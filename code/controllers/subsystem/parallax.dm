/// Define for the pickweight value where you get no parallax
#define PARALLAX_NONE "parallax_none"

SUBSYSTEM_DEF(parallax)
	name = "Parallax"
	wait = 2
	flags = SS_POST_FIRE_TIMING | SS_BACKGROUND
	priority = FIRE_PRIORITY_PARALLAX
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	var/list/currentrun
	var/planet_x_offset = 128
	var/planet_y_offset = 128
	/// A random parallax layer that we sent to every player
	var/atom/movable/screen/parallax_layer/random/random_layer
	/// Weighted list with the parallax layers we could spawn
	var/random_parallax_weights = list(
		/atom/movable/screen/parallax_layer/random/space_gas = 35,
		/atom/movable/screen/parallax_layer/random/asteroids = 35,
		PARALLAX_NONE = 30,
	)
	/// List of parallax cells by z level (list(z = list(y = list(datum/parallax_cell))))
	var/list/list/list/datum/parallax_cell/parallax_cells_by_z = list()

/datum/controller/subsystem/parallax/Initialize()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_NEW_Z, PROC_REF(prepare_parallax_cells))
	prepare_parallax_cells(null)

/datum/controller/subsystem/parallax/Destroy()
	for(var/list/column in parallax_cells_by_z)
		for(var/list/row in parallax_cells_by_z)
			QDEL_LIST(row)
	parallax_cells_by_z.Cut()
	return ..()

/datum/controller/subsystem/parallax/proc/prepare_parallax_cells(datum/source)
	SIGNAL_HANDLER
	for(var/z in (length(parallax_cells_by_z) + 1) to world.maxz)
		var/list/new_rows = list()
		for(var/y in 1 to PARALLAX_CELL(255))
			var/list/new_columns = list()
			for(var/x in 1 to PARALLAX_CELL(255))
				var/datum/parallax_cell/new_guy = new(x, y, z)
				new_columns += new_guy
			new_rows += list(new_columns)
		parallax_cells_by_z += list(new_rows)

/// Returns all the parallax cells contained within a given bound
/datum/controller/subsystem/parallax/proc/get_cells_by_bound(lower_x, lower_y, upper_x, upper_y, z)
	var/list/hand_back = list()
	var/list/cells_in_z = parallax_cells_by_z[z]
	for(var/y in lower_y to upper_y)
		var/list/cells_in_y = cells_in_z[y]
		for(var/x in lower_x to upper_x)
			hand_back += cells_in_y[x]
	return hand_back

/// Holds/provides information about parallax background objects to listeners
/datum/parallax_cell
	var/list/datum/parallax_object/members = list()
	var/x
	var/y
	var/z

/datum/parallax_cell/New(x, y, z)
	. = ..()
	src.x = x
	src.y = y
	src.z = z

/datum/parallax_cell/Destroy(force)
	for(var/datum/parallax_object/member in members)
		member_left(member)
	members = null
	return ..()

/datum/parallax_cell/proc/member_entered(datum/parallax_object/member)
	members += member
	member.vacation_homes += src
	SEND_SIGNAL(src, COMSIG_PARALLAX_OBJECT_ENTERED, member)

/datum/parallax_cell/proc/member_left(datum/parallax_object/member)
	members -= member
	member.vacation_homes -= src
	SEND_SIGNAL(src, COMSIG_PARALLAX_OBJECT_LEFT, member)

/proc/place_skull(x, y, z)
	var/datum/parallax_object/skull/wooooo = new()
	wooooo.place_visual(x, y, z)

/datum/parallax_object/skull

/datum/parallax_object/skull/generate_visuals()
	var/obj/effect/visuals = ..()
	visuals.icon = 'icons/effects/effects.dmi'
	visuals.icon_state = "cult_master_logo"
	return visuals

/obj/effect/abstract/parallax_object_holder
	blend_mode = BLEND_ADD
	plane = PLANE_SPACE_PARALLAX
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/datum/parallax_object
	/// Object we actually relay to the map
	var/obj/effect/abstract/parallax_object_holder/visuals
	/// Amount of pixels to move for every 32 pixels moved by the player. try to avoid staying in fractional values if you can it can lead to wierd looking steps
	var/speed = 32
	/// Visual anchor x on the map (in pixels), this is where the parallax object centers itself (if you're on this tile, it's right below you)
	var/visual_x = 0
	/// Visual position y on the map (in pixels), this is where the parallax object centers itself (if you're on this tile, it's right below you)
	var/visual_y = 0

	// You can think about physical position like a cone expanding from the "camera". If you're twice as far away
	// (speed = 16) as the rest of the world you will have twice the amount of "space" you can move in, etc
	/// Physical x on the imagined layers behind the station (in physical pixels), scales with speed (so a speed of 16 will have a range of 255 * 32 * 32/16 physical pixels, etc)
	var/physical_x = 0
	/// Physical y on the imagined layers behind the station (in physical pixels), scales with speed (so a speed of 16 will have a range of 255 * 32 * 32/16 physical pixels, etc)
	var/physical_y = 0

	/// The z layer we're trying to draw on (WE MAYBE CAN MAKE THIS WRAP JUST NEED TO FIGURE OUT Z TRANSITION HELL WORLD)
	var/z_coord = 0

	/// The parallax cells we are currently in, if any
	var/list/datum/parallax_cell/vacation_homes = list()

/datum/parallax_object/New()
	. = ..()
	visuals = generate_visuals()

/datum/parallax_object/Destroy(force)
	for(var/datum/parallax_cell/cell as anything in vacation_homes)
		cell.member_left(src)
	vacation_homes = null
	QDEL_NULL(visuals)
	return ..()

/datum/parallax_object/proc/generate_visuals()
	visuals = new()
	var/static/uid = 0
	visuals.render_target = "*parallax_[uid]_object"
	uid = WRAP_UID(uid + 1)
	return visuals

/datum/parallax_object/proc/update_cells()
	var/parallax_span = PARALLAX_SPAN * 32/speed
	var/list/new_cells = SSparallax.get_cells_by_bound(
		PARALLAX_CELL(visual_x / 32 - parallax_span), PARALLAX_CELL(visual_y / 32 - parallax_span),
		PARALLAX_CELL(visual_x / 32 + parallax_span), PARALLAX_CELL(visual_y / 32 + parallax_span), z_coord)

	for(var/datum/parallax_cell/old_fella as anything in vacation_homes - new_cells)
		old_fella.member_left(src)
	for(var/datum/parallax_cell/new_fella as anything in new_cells - vacation_homes)
		new_fella.member_entered(src)
	vacation_homes = new_cells

/// Places a parallax object at some pixel position on the map (it will be centered if you stand at this tile)
/datum/parallax_object/proc/place_visual(x, y, z)
	visual_x = x
	visual_y = y
	z_coord = z
	physical_x = visual_x * 32/speed
	physical_y = visual_y * 32/speed

	update_cells()
	SEND_SIGNAL(src, COMSIG_PARALLAX_PLACED)

/// Moves a parallax object by x/y physical pixels (+ is right/up)
/// Will behave strangely if you do this with an x or y > PARALLAX_RANGE * 32 * 32/speed
/datum/parallax_object/proc/move_physical(x, y, animate_speed)
	physical_x += x
	physical_y += y
	visual_x = physical_x * speed/32
	visual_y = physical_y * speed/32
	update_cells()
	SEND_SIGNAL(src, COMSIG_PARALLAX_MOVED, animate_speed)

/datum/parallax_object/proc/set_speed(new_speed)
	var/old_speed = src.speed
	src.speed = new_speed
	physical_x = visual_x * 32/new_speed
	physical_y = visual_y * 32/new_speed
	update_cells()
	SEND_SIGNAL(src, COMSIG_PARALLAX_SET_SPEED, old_speed, new_speed)

//These are cached per client so needs to be done asap so people joining at roundstart do not miss these.
/datum/controller/subsystem/parallax/PreInit()
	. = ..()

	set_random_parallax_layer(pick_weight(random_parallax_weights))

	planet_y_offset = rand(100, 160)
	planet_x_offset = rand(100, 160)

/datum/controller/subsystem/parallax/fire(resumed = FALSE)
	if (!resumed)
		src.currentrun = GLOB.clients.Copy()

	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while(length(currentrun))
		var/client/processing_client = currentrun[currentrun.len]
		currentrun.len--
		if (QDELETED(processing_client) || !processing_client.eye)
			if (MC_TICK_CHECK)
				return
			continue

		var/atom/movable/movable_eye = processing_client.eye
		if(!istype(movable_eye))
			continue

		while(isloc(movable_eye.loc) && !isturf(movable_eye.loc))
			movable_eye = movable_eye.loc
		//get the last movable holding the mobs eye

		if(movable_eye == processing_client.movingmob)
			if (MC_TICK_CHECK)
				return
			continue

		//eye and the last recorded eye are different, and the last recorded eye isnt just the clients mob
		if(!isnull(processing_client.movingmob))
			LAZYREMOVE(processing_client.movingmob.client_mobs_in_contents, processing_client.mob)
		LAZYADD(movable_eye.client_mobs_in_contents, processing_client.mob)

		processing_client.movingmob = movable_eye
		if (MC_TICK_CHECK)
			return
	currentrun = null

/// Generate a random layer for parallax
/datum/controller/subsystem/parallax/proc/set_random_parallax_layer(picked_parallax)
	if(picked_parallax == PARALLAX_NONE)
		return

	random_layer = new picked_parallax(null,  /* hud_owner = */ null, /* owner = */ null, /* template = */ TRUE)
	RegisterSignal(random_layer, COMSIG_QDELETING, PROC_REF(clear_references))
	random_layer.get_random_look()

/// Change the random parallax layer after it's already been set. update_player_huds = TRUE will also replace them in the players client images, if it was set
/datum/controller/subsystem/parallax/proc/swap_out_random_parallax_layer(atom/movable/screen/parallax_layer/new_type, update_player_huds = TRUE)
	set_random_parallax_layer(new_type)

	if(!update_player_huds)
		return

	//Parallax is one of the first things to be set (during client join), so rarely is anything fast enough to swap it out
	//That's why we need to swap the layers out for fast joining clients :/
	for(var/client/client as anything in GLOB.clients)
		// gotta clear things out
		client?.parallax_rock?.set_layer_settings(0, FALSE, FALSE)
		client.mob?.hud_used?.update_parallax_pref()

/datum/controller/subsystem/parallax/proc/clear_references()
	SIGNAL_HANDLER

	random_layer = null

/// Called at the end of SSstation setup, in-case we want to run some code that would otherwise be too early to run (like GLOB. stuff)
/datum/controller/subsystem/parallax/proc/post_station_setup()
	random_layer?.apply_global_effects()

/// Return the most dominant color, if we have a colored background (mostly nebula gas)
/datum/controller/subsystem/parallax/proc/get_parallax_color()
	var/atom/movable/screen/parallax_layer/random/space_gas/gas = random_layer
	if(!istype(gas))
		return

	return gas.parallax_color

#undef PARALLAX_NONE
