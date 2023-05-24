#define FLOW_PATH_END 1
/// Datum that describes the shortest path between a source turf and any turfs within a distance
/datum/path_map
	/// Assoc list of turf -> a list of the turf one step closer on the path (ordered with the fastest path first)
	/// Arranged in discovery order, so the last turf here will be the furthest from the start
	var/list/next_closest = list()
	/// List of distances from the starting turf, each index lines up with the next_closest list
	var/list/distances = list()
	/// Our starting turf, the location this map feeds into
	var/turf/start
	/// The tick we were completed on, in case you want to hold onto this for a bit
	var/creation_time
	/// A list describing the access used to create this pathmap
	var/list/access

/**
 * Takes a turf to path to, returns the shortest path to it at the time of this datum's creation
 *
 * skip_first - If we should drop the first step in the path. Used to avoid stepping where we already are
 */
/datum/path_map/proc/get_path_to(turf/path_to, skip_first = FALSE)
	return generate_path(path_to, skip_first)

/**
 * Takes a turf to start from, returns a path to the source turf of this datum
 *
 * skip_first - If we should drop the first step in the path. Used to avoid stepping where we already are
 */
/datum/path_map/proc/get_path_from(turf/path_from, skip_first = FALSE)
	return generate_path(path_from, skip_first, reverse = TRUE)

/**
 * Takes a turf to use as the other end, returns the path between the source node and it
 *
 * skip_first - If we should drop the first step in the path. Used to avoid stepping where we already are
 * reverse - If true, "reverses" the path generated. You'd want to use this for generating a path to the source node itself
 */
/datum/path_map/proc/generate_path(turf/other_end, skip_first = FALSE, reverse = FALSE)
	var/list/path = list()
	var/turf/next_turf = other_end
	// Cache for sonic speed
	var/next_closest = src.next_closest
	while(next_turf != FLOW_PATH_END || next_turf == null)
		path += next_turf
		next_turf = next_closest[next_turf] // We take the first entry cause that's the turf

	// This makes sense from a consumer level, I hate double negatives too I promise
	if(!reverse)
		path = reverseList(path)
	if(skip_first && length(path) > 0)
		path.Cut(1,2)
	return path

/datum/path_map/proc/display(delay = 10 SECONDS)
	for(var/index in 1 to length(distances))
		var/turf/next_turf = next_closest[index]
		next_turf.maptext = "[distances[index]]"
		next_turf.color = COLOR_NAVY
		animate(next_turf, color = null, delay)
		animate(maptext = "", world.tick_lag)

/datum/path_map/proc/sanity_check()
	for(var/index in 1 to length(distances))
		var/turf/next_turf = next_closest[index]
		var/list/path = get_path_from(next_turf)
		if(length(path) != distances[index] + 1)
			stack_trace("[next_turf] had a distance of [length(path)] instead of the expected [distances[index]]")
		if(path.Find(next_turf) != 1)
			stack_trace("Starting turf [next_turf] was not the first entry in its list (instead it's at [path.Find(next_turf)])")
		path = get_path_to(next_turf)
		if(length(path) != distances[index] + 1)
			stack_trace("[next_turf] had a distance of [length(path)] instead of the expected [distances[index]]")
		if(path.Find(next_turf) != length(path))
			stack_trace("Starting turf [next_turf] was not the last entry in its list (instead it's at [path.Find(next_turf)])")

/// Single source shortest path
/// Generates a flow map of a reachable turf -> the turf next closest to the map's center
/datum/pathfind/sssp
	/// Ever expanding list of turfs to visit/visited, associated with the turf that's next closest to them
	var/list/working_queue
	/// List of distances, each entry mirrors an entry in the working_queue
	var/list/working_distances
	/// Our current position in the working queue
	var/working_index

/datum/pathfind/sssp/start()
	. = ..()
	if(!.)
		return .
	working_queue = list()
	working_distances = list()
	working_queue[start] = FLOW_PATH_END
	working_distances += 0
	working_index = 0
	return TRUE

/datum/pathfind/sssp/search_step()
	. = ..()
	if(!.)
		return
	while(working_index < length(working_queue))
		working_index += 1

		var/turf/next_turf = working_queue[working_index]
		var/distance = working_distances[working_index] + 1
		if(distance > max_distance)
			if(TICK_CHECK)
				return TRUE
			continue
		for(var/turf/adjacent in TURF_NEIGHBORS(next_turf))
			// Already have a path? then we're gooood baby
			if(working_queue[adjacent])
				continue

			// If it's blocked, go home
			if(!CAN_STEP(next_turf, adjacent, simulated_only, caller, access, avoid))
				continue
			// I want to prevent diagonal moves around corners
			// We do this first because blocked diagonals are more common then non blocked ones.
			if(next_turf.x != adjacent.x && next_turf.y != adjacent.y)
				var/movement_dir = get_dir(next_turf, adjacent)
				// If either of the move components would bump into something, replace it with an explicit move around
				var/turf/vertical_move = get_step(next_turf, movement_dir & (NORTH|SOUTH))
				var/turf/horizontal_move = get_step(next_turf, movement_dir & (EAST|WEST))
				if(!working_queue[vertical_move])
					if(CAN_STEP(next_turf, vertical_move, simulated_only, caller, access, avoid))
						working_queue[vertical_move] = next_turf
						working_distances += distance
					else
						// Can't do a vertical move? let's do a horizontal move first
						if(!working_queue[horizontal_move])
							working_queue[horizontal_move] = next_turf
							working_distances += distance
						continue
				if(!working_queue[horizontal_move])
					if(CAN_STEP(next_turf, horizontal_move, simulated_only, caller, access, avoid))
						working_queue[horizontal_move] = next_turf
						working_distances += distance
					else
						if(!working_queue[vertical_move])
							working_queue[vertical_move] = next_turf
							working_distances += distance
						continue

			// Otherwise, this new turf's next closest turf is our source, so we'll mark as such and continue
			// This is a breadth first search, we're essentially moving out in layers from the start position
			working_queue[adjacent] = next_turf
			working_distances += distance

		if(TICK_CHECK)
			return TRUE
	return TRUE

/datum/pathfind/sssp/finished()
	var/datum/path_map/flow_map = new()
	flow_map.start = start
	flow_map.access = access
	flow_map.next_closest = working_queue
	flow_map.distances = working_distances
	flow_map.creation_time = world.time
	hand_back(flow_map)
	return ..()

/// Takes a pathmap as input, expands it to a new range
/// LEMON TODO: this is likely a better proc to be on the map itself, since you can use callbacks and such to acomplish our goals here
/// Also figure out if this is actually worth having or not, yeah? (I am pretty sure it'd be useful for bees and such)
/datum/pathfind/sssp/proc/expand_on(datum/path_map/flow_map)
	working_queue = flow_map.next_closest
	working_distances = flow_map.distances
	working_index = working_distances.len
	var/max_dist = working_distances[working_distances.len]
	while(working_distances[working_index] == working_index)
		working_index -= 1

