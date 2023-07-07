///Atom that manages and controls multiple planes. It's an atom so we can hook into add_filter etc. Multiple controllers can control one plane.
///Of note: plane master controllers are currently not very extensively used, because render plates fill a semi similar niche
///This could well change someday, and I'd like to keep this stuff around, so we use it for a few cases just out of convenience
/atom/movable/plane_master_controller
	///List of planes as defines in this controllers control
	var/list/controlled_planes = list()
	///hud that owns this controller
	var/datum/hud/owner_hud

INITIALIZE_IMMEDIATE(/atom/movable/plane_master_controller)

///Ensures that all the planes are correctly in the controlled_planes list.
/atom/movable/plane_master_controller/Initialize(mapload, datum/hud/hud)
	. = ..()
	if(!istype(hud))
		return
	owner_hud = hud

#warn todo: handle planes leaving/joining the mob's view
/atom/movable/plane_master_controller/proc/get_planes()
	// This loop exists JUST as a sanity check. If it ever gets too expensive, yeet it
	for(var/controlled in controlled_planes)
		if(!length(owner_hud.get_true_plane_masters(controlled))) //If we looked for a hud that isn't instanced, just keep going
			stack_trace("[controlled] isn't a valid plane master value for [owner_hud.type], are you sure it exists in the first place?")
			return
	return owner_hud.get_highest_true_planes(controlled_planes)

///Full override so we can just use filterrific
/atom/movable/plane_master_controller/add_filter(name, priority, list/params)
	. = ..()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.add_filter(name, priority, params)

///Full override so we can just use filterrific
/atom/movable/plane_master_controller/remove_filter(name_or_names)
	. = ..()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.remove_filter(name_or_names)

/atom/movable/plane_master_controller/update_filters()
	. = ..()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.update_filters()

///Gets all filters for this controllers plane masters
/atom/movable/plane_master_controller/proc/get_filters(name)
	. = list()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		. += pm_iterator.get_filter(name)

///Transitions all filters owned by this plane master controller
/atom/movable/plane_master_controller/transition_filter(name, list/new_params, time, easing, loop)
	. = ..()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.transition_filter(name, new_params, time, easing, loop)

///Adds a filter if one does not already exist
/atom/movable/plane_master_controller/proc/add_if_no_filter(name, priority, list/params)
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		if(pm_iterator.get_filter(name))
			continue
		pm_iterator.add_filter(name, priority, params)

///Full override so we can just use filterrific
/atom/movable/plane_master_controller/add_atom_colour(coloration, colour_priority)
	. = ..()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.add_atom_colour(coloration, colour_priority)


///Removes an instance of colour_type from the atom's atom_colours list
/atom/movable/plane_master_controller/remove_atom_colour(colour_priority, coloration)
	. = ..()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.remove_atom_colour(colour_priority, coloration)


///Resets the atom's color to null, and then sets it to the highest priority colour available
/atom/movable/plane_master_controller/update_atom_colour()
	for(var/atom/movable/screen/plane_master/pm_iterator as anything in get_planes())
		pm_iterator.update_atom_colour()


/// Exists for convienience when referencing all game render plates
/atom/movable/plane_master_controller/game
	name = PLANE_MASTERS_GAME
	controlled_planes = list(
		RENDER_PLANE_GAME
	)

/// Exists for convienience when referencing all non-master render plates.
/// This is the whole game and the UI, but not the escape menu.
/atom/movable/plane_master_controller/non_master
	name = PLANE_MASTERS_NON_MASTER
	controlled_planes = list(
		RENDER_PLANE_GAME,
		RENDER_PLANE_NON_GAME,
	)

/// Exists for convienience when referencing all game render plates
/atom/movable/plane_master_controller/colorblind
	name = PLANE_MASTERS_COLORBLIND
	controlled_planes = list(
		RENDER_PLANE_MASTER
	)

