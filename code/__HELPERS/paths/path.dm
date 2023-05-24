#warn LEMON TODO
// I would like to make pathfinding work theoretically reusable
// It seems like it would be useful to build out a flow map for an area, and reuse it for multiple requests
// This comes to mind most for stuff like bees
// Half the work here is done, in that ids are now passed around as access. However, I'd also like to be able to pass around "pass rules"
// I want to be able to compare two atom's canpass information, and use it to cache pathfinding attempts
// This will require building a datum to hold everything canastarpass might want

/**
 * This is the proc you use whenever you want to have pathfinding more complex than "try stepping towards the thing".
 * If no path was found, returns an empty list, which is important for bots like medibots who expect an empty list rather than nothing.
 * It will yield until a path is returned, using magic
 *
 * Arguments:
 * * caller: The movable atom that's trying to find the path
 * * end: What we're trying to path to. It doesn't matter if this is a turf or some other atom, we're gonna just path to the turf it's on anyway
 * * max_distance: The maximum number of steps we can take in a given path to search (default: 30, 0 = infinite)
 * * mintargetdistance: Minimum distance to the target before path returns, could be used to get near a target, but not right to it - for an AI mob with a gun, for example.
 * * access: A list representing what access we have and what doors we can open.
 * * simulated_only: Whether we consider turfs without atmos simulation (AKA do we want to ignore space)
 * * exclude: If we want to avoid a specific turf, like if we're a mulebot who already got blocked by some turf
 * * skip_first: Whether or not to delete the first item in the path. This would be done because the first item is the starting tile, which can break movement for some creatures.
 * * diagonal_handling: defines how we handle diagonal moves. see __DEFINES/path.dm
 */
/proc/get_path_to(atom/movable/caller, atom/end, max_distance = 30, mintargetdist, access=list(), simulated_only = TRUE, turf/exclude, skip_first=TRUE, diagonal_handling=DIAGONAL_REMOVE_CLUNKY)
	var/list/hand_around = list()
	// We're guarenteed that list will be the first list in pathfinding_finished's argset because of how callback handles the arguments list
	var/datum/callback/await = CALLBACK(GLOBAL_PROC, /proc/pathfinding_finished, hand_around)
	if(!SSpathfinder.pathfind(caller, end, max_distance, mintargetdist, access, simulated_only, exclude, skip_first, diagonal_handling, await))
		return list()

	UNTIL(length(hand_around))
	var/list/return_val = hand_around[1]
	if(!islist(return_val) || (QDELETED(caller) || QDELETED(end))) // It's trash, just hand back null to make it easy
		return list()
	return return_val

/atom/movable/var/datum/path_map/map

/atom/movable/proc/sssp(max_distance = 30, access=list(), simulated_only = TRUE, turf/exclude)
	map = get_sssp(src, max_distance, access, simulated_only, exclude)

/proc/get_sssp(atom/movable/caller, max_distance = 30, access=list(), simulated_only = TRUE, turf/exclude)
	var/list/hand_around = list()
	// We're guarenteed that list will be the first list in pathfinding_finished's argset because of how callback handles the arguments list
	var/datum/callback/await = CALLBACK(GLOBAL_PROC, /proc/pathfinding_finished, hand_around)
	if(!SSpathfinder.build_map(caller, max_distance, access, simulated_only, exclude, await))
		return null

	UNTIL(length(hand_around))
	var/datum/path_map/return_val = hand_around[1]
	if(!istype(return_val, /datum/path_map) || (QDELETED(caller))) // It's trash, just hand back null to make it easy
		return null
	return return_val


/// Uses funny pass by reference bullshit to take the output created by pathfinding, and insert it into a return list
/// We'll be able to use this return list to tell a sleeping proc to continue execution
/proc/pathfinding_finished(list/return_list, hand_back)
	// We use += here to behave nicely with lists
	return_list += LIST_VALUE_WRAP_LISTS(hand_back)

/// The datum used to handle the JPS pathfinding, completely self-contained
/datum/pathfind
	/// The thing that we're actually trying to path for
	var/atom/movable/caller
	/// The turf where we started at
	var/turf/start

	// general pathfinding vars/args
	/// An list representing what access we have and what doors we can open
	var/list/access
	/// I don't know what this does vs , but they limit how far we can search before giving up on a path
	var/max_distance = 30
	/// Space is big and empty, if this is TRUE then we ignore pathing through unsimulated tiles
	var/simulated_only
	/// A specific turf we're avoiding, like if a mulebot is being blocked by someone t-posing in a doorway we're trying to get through
	var/turf/avoid
	/// The callback to invoke when we're done working, passing in the completed var/list/path
	var/datum/callback/on_finish

/datum/pathfind/New(atom/movable/caller, access, max_distance, simulated_only, avoid, datum/callback/on_finish)
	src.caller = caller
	src.access = access
	src.max_distance = max_distance
	src.simulated_only = simulated_only
	src.avoid = avoid
	src.on_finish = on_finish

/datum/pathfind/Destroy(force, ...)
	. = ..()
	SSpathfinder.active_pathing -= src
	SSpathfinder.currentrun -= src
	hand_back(null)

/**
 * "starts" off the pathfinding, by storing the values this datum will need to work later on
 *  returns FALSE if it fails to setup properly, TRUE otherwise
 */
/datum/pathfind/proc/start()
	start = get_turf(caller)
	if(!start)
		stack_trace("Invalid pathfinding start")
		return FALSE
	return TRUE

/**
 * search_step() is the workhorse of pathfinding. It'll do the searching logic, and will slowly build up a path
 * returns TRUE if everything is stable, FALSE if the pathfinding logic has failed, and we need to abort
 */
/datum/pathfind/proc/search_step()
	if(QDELETED(caller))
		return FALSE
	return TRUE

/**
 * early_exit() is called when something goes wrong in processing, and we need to halt the pathfinding NOW
 */
/datum/pathfind/proc/early_exit()
	hand_back(null)
	qdel(src)

/**
 * Cleanup pass for the pathfinder. This tidies up the path, and fufills the pathfind's obligations
 */
/datum/pathfind/proc/finished()
	qdel(src)

/**
 * Call to return a value to whoever spawned this pathfinding work
 * Will fail if it's already been called
 */
/datum/pathfind/proc/hand_back(value)
	if(!on_finish)
		return
	on_finish.Invoke(value)
	on_finish = null

/**
 * Processes a path (list of turfs), removes any diagonal moves that would lead to a weird bump
 *
 * path - The path to process down
 * caller - The source object for the path
 * access - What access, if any to use when checking pasables
 * simulated_only - If we are not allowed to pass space turfs
 * avoid - A turf to be avoided
 */
/proc/remove_clunky_diagonals(list/path, atom/movable/caller, list/access, simulated_only, turf/avoid)
	if(length(path) < 2)
		return path
	var/list/modified_path = list()

	for(var/i in 1 to length(path) - 1)
		var/turf/current_turf = path[i]
		modified_path += current_turf
		var/turf/next_turf = path[i+1]
		var/movement_dir = get_dir(current_turf, next_turf)
		if(!(movement_dir & (movement_dir - 1))) //cardinal movement, no need to verify
			continue
		//If the first diagonal movement step is invalid (north/south), replace with a sidestep first, with an implied vertical step in next_turf
		var/vertical_only = movement_dir & (NORTH|SOUTH)
		if(!CAN_STEP(current_turf,get_step(current_turf, vertical_only), simulated_only, caller, access, avoid))
			modified_path += get_step(current_turf, movement_dir & ~vertical_only)
	modified_path += path[length(path)]

	return modified_path

/**
 * Processes a path (list of turfs), removes any diagonal moves
 *
 * path - The path to process down
 * caller - The source object for the path
 * access - What access, if any to use when checking pasables
 * simulated_only - If we are not allowed to pass space turfs
 * avoid - A turf to be avoided
 */
/proc/remove_diagonals(list/path, atom/movable/caller, list/access, simulated_only, turf/avoid)
	if(length(path) < 2)
		return path
	var/list/modified_path = list()

	for(var/i in 1 to length(path) - 1)
		var/turf/current_turf = path[i]
		modified_path += current_turf
		var/turf/next_turf = path[i+1]
		var/movement_dir = get_dir(current_turf, next_turf)
		if(!(movement_dir & (movement_dir - 1))) //cardinal movement, no need to verify
			continue
		var/vertical_only = movement_dir & (NORTH|SOUTH)
		// If we can't go directly north/south, we will first go to the side,
		if(!CAN_STEP(current_turf,get_step(current_turf, vertical_only), simulated_only, caller, access, avoid))
			modified_path += get_step(current_turf, movement_dir & ~vertical_only)
		else // Otherwise, we'll first go north/south, then to the side
			modified_path += get_step(current_turf, vertical_only)
	modified_path += path[length(path)]

	return modified_path

/**
 * For seeing if we can actually move between 2 given turfs while accounting for our access and the caller's pass_flags
 *
 * Assumes destinantion turf is non-dense - check and shortcircuit in code invoking this proc to avoid overhead.
 * Makes some other assumptions, such as assuming that unless declared, non dense objects will not block movement.
 * It's fragile, but this is VERY much the most expensive part of JPS, so it'd better be fast
 *
 * Arguments:
 * * caller: The movable, if one exists, being used for mobility checks to see what tiles it can reach
 * * access: A list that decides if we can gain access to doors that would otherwise block a turf
 * * simulated_only: Do we only worry about turfs with simulated atmos, most notably things that aren't space?
 * * no_id: When true, doors with public access will count as impassible
*/
/turf/proc/LinkBlockedWithAccess(turf/destination_turf, atom/movable/caller, list/access, no_id = FALSE)
	if(destination_turf.x != x && destination_turf.y != y) //diagonal
		var/in_dir = get_dir(destination_turf,src) // eg. northwest (1+8) = 9 (00001001)
		var/first_step_direction_a = in_dir & 3 // eg. north   (1+8)&3 (0000 0011) = 1 (0000 0001)
		var/first_step_direction_b = in_dir & 12 // eg. west   (1+8)&12 (0000 1100) = 8 (0000 1000)

		for(var/first_step_direction in list(first_step_direction_a,first_step_direction_b))
			var/turf/midstep_turf = get_step(destination_turf,first_step_direction)
			var/way_blocked = midstep_turf.density || LinkBlockedWithAccess(midstep_turf, caller, access, no_id) || midstep_turf.LinkBlockedWithAccess(destination_turf, caller, access, no_id)
			if(!way_blocked)
				return FALSE
		return TRUE
	var/actual_dir = get_dir(src, destination_turf)

	/// These are generally cheaper than looping contents so they go first
	switch(destination_turf.pathing_pass_method)
		// This is already assumed to be true
		//if(TURF_PATHING_PASS_DENSITY)
		//	if(destination_turf.density)
		//		return TRUE
		if(TURF_PATHING_PASS_PROC)
			if(!destination_turf.CanAStarPass(access, actual_dir, caller, no_id))
				return TRUE
		if(TURF_PATHING_PASS_NO)
			return TRUE

	var/static/list/directional_blocker_cache = typecacheof(list(/obj/structure/window, /obj/machinery/door/window, /obj/structure/railing, /obj/machinery/door/firedoor/border_only))
	// Source border object checks
	for(var/obj/border in src)
		if(!directional_blocker_cache[border.type])
			continue
		if(!border.density && border.can_astar_pass == CANASTARPASS_DENSITY)
			continue
		if(!border.CanAStarPass(access, actual_dir, no_id = no_id))
			return TRUE

	// Destination blockers check
	var/reverse_dir = get_dir(destination_turf, src)
	for(var/obj/iter_object in destination_turf)
		// This is an optimization because of the massive call count of this code
		if(!iter_object.density && iter_object.can_astar_pass == CANASTARPASS_DENSITY)
			continue
		if(!iter_object.CanAStarPass(access, reverse_dir, caller, no_id))
			return TRUE
	return FALSE

