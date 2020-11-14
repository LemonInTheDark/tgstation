/turf
	//used for temperature calculations
	var/thermal_conductivity = 0.8
	var/heat_capacity = 1

	///list of turfs adjacent to us that air can flow onto
	var/list/atmos_adjacent_turfs
	///bitfield of dirs in which an open, gasmoving turf exists. Used by semiclosed turfs like windows to do superconduction
	var/atmos_open_turfs = NONE
	///bitfield of dirs in which we are superconducitng
	var/atmos_supeconductivity = NONE

	//used to determine whether we should archive
	var/archived_cycle = 0
	var/current_cycle = 0

	//used for mapping and for breathing while in walls (because that's a thing that needs to be accounted for...)
	//string parsed by /datum/gas/proc/copy_from_turf
	var/initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	//approximation of MOLES_O2STANDARD and MOLES_N2STANDARD pending byond allowing constant expressions to be embedded in constant strings
	// If someone will place 0 of some gas there, SHIT WILL BREAK. Do not do that.

/turf/open
	//used for spacewind
	var/pressure_difference = 0
	var/pressure_direction = 0

	var/datum/excited_group/excited_group
	var/excited = FALSE
	var/datum/gas_mixture/turf/air

	var/obj/effect/hotspot/active_hotspot
	var/planetary_atmos = FALSE //air will revert to initial_gas_mix

	var/list/atmos_overlay_types //gas IDs of current active gas overlays
	var/significant_share_ticker = 0
	#ifdef TRACK_MAX_SHARE
	var/max_share = 0
	#endif

GLOBAL_LIST_EMPTY(planetary) //Lets cache static planetary mixes
/turf/open/Initialize()
	if(!blocks_air)
		if(!planetary_atmos)
			air = new
			air.copy_from_turf(src)
		else
			if(!GLOB.planetary[initial_gas_mix])
				var/datum/gas_mixture/immutable/planetary/mix = new
				mix.parse_string_immutable(initial_gas_mix)
				GLOB.planetary[initial_gas_mix] = mix
			air = GLOB.planetary[initial_gas_mix]
	. = ..()

/turf/open/Destroy()
	if(active_hotspot)
		QDEL_NULL(active_hotspot)
	// Adds the adjacent turfs to the current atmos processing
	for(var/T in atmos_adjacent_turfs)
		SSair.add_to_active(T, FALSE)
	return ..()

/////////////////GAS MIXTURE PROCS///////////////////

/turf/open/assume_air(datum/gas_mixture/giver) //use this for machines to adjust air
	if(!giver || planetary_atmos)
		return FALSE
	air.merge(giver)
	update_visuals()
	return TRUE

/turf/open/remove_air(amount)
	var/datum/gas_mixture/ours = return_air()
	var/datum/gas_mixture/removed = ours.remove(amount)
	update_visuals()
	return removed

/turf/open/proc/copy_air_with_tile(turf/open/T)
	if(istype(T))
		air.copy_from(T.air)

/turf/open/proc/copy_air(datum/gas_mixture/copy)
	if(copy)
		air.copy_from(copy)

/turf/return_air()
	RETURN_TYPE(/datum/gas_mixture)
	var/datum/gas_mixture/GM = new
	GM.copy_from_turf(src)
	return GM

/turf/open/return_air()
	RETURN_TYPE(/datum/gas_mixture)
	return air

/turf/open/return_analyzable_air()
	return return_air()

/turf/should_atmos_process(datum/gas_mixture/air, exposed_temperature)
	return (exposed_temperature >= heat_capacity || to_be_destroyed)

/turf/atmos_expose(datum/gas_mixture/air, exposed_temperature)
	if(exposed_temperature >= heat_capacity)
		to_be_destroyed = TRUE
	if(to_be_destroyed && exposed_temperature >= max_fire_temperature_sustained)
		max_fire_temperature_sustained = min(exposed_temperature, max_fire_temperature_sustained + heat_capacity / 4) //Ramp up to 100% yeah?
	if(to_be_destroyed && !changing_turf)
		burn()

/turf/open/atmos_expose(datum/gas_mixture/air, exposed_temperature)
	if(exposed_temperature >= heat_capacity)
		to_be_destroyed = TRUE
	if(to_be_destroyed && exposed_temperature >= max_fire_temperature_sustained)
		max_fire_temperature_sustained = min(exposed_temperature, max_fire_temperature_sustained + heat_capacity / 4) //Ramp up to 100% yeah?
	if(to_be_destroyed && !changing_turf && !active_hotspot)
		burn()

/turf/proc/burn()
	burn_tile()
	var/chance_of_deletion
	if (heat_capacity) //beware of division by zero
		chance_of_deletion = max_fire_temperature_sustained / heat_capacity * 8 //there is no problem with prob(23456), min() was redundant --rastaf0
	else
		chance_of_deletion = 100
	if(prob(chance_of_deletion))
		Melt()
		max_fire_temperature_sustained = 0
	else
		to_be_destroyed = FALSE

/turf/temperature_expose(datum/gas_mixture/air, exposed_temperature)
	atmos_expose(air, exposed_temperature)

/turf/open/temperature_expose(datum/gas_mixture/air, exposed_temperature)
	SEND_SIGNAL(src, COMSIG_TURF_EXPOSE, air, exposed_temperature)
	check_atmos_process(null, air, exposed_temperature) //Manually do this to avoid needing to use elements, don't want 200 second atom init times

/turf/open/proc/archive()
	air.archive()
	archived_cycle = SSair.times_fired

/////////////////////////GAS OVERLAYS//////////////////////////////


/turf/open/proc/update_visuals()

	var/list/atmos_overlay_types = src.atmos_overlay_types // Cache for free performance
	var/list/new_overlay_types = list()
	var/static/list/nonoverlaying_gases = typecache_of_gases_with_no_overlays()

	if(!air) // 2019-05-14: was not able to get this path to fire in testing. Consider removing/looking at callers -Naksu
		if (atmos_overlay_types)
			for(var/overlay in atmos_overlay_types)
				vis_contents -= overlay
			src.atmos_overlay_types = null
		return

	var/list/gases = air.gases

	for(var/id in gases)
		if (nonoverlaying_gases[id])
			continue
		var/gas = gases[id]
		var/gas_meta = gas[GAS_META]
		var/gas_overlay = gas_meta[META_GAS_OVERLAY]
		if(gas_overlay && gas[MOLES] > gas_meta[META_GAS_MOLES_VISIBLE])
			new_overlay_types += gas_overlay[min(TOTAL_VISIBLE_STATES, CEILING(gas[MOLES] / MOLES_GAS_VISIBLE_STEP, 1))]

	if (atmos_overlay_types)
		for(var/overlay in atmos_overlay_types-new_overlay_types) //doesn't remove overlays that would only be added
			vis_contents -= overlay

	if (length(new_overlay_types))
		if (atmos_overlay_types)
			vis_contents += new_overlay_types - atmos_overlay_types //don't add overlays that already exist
		else
			vis_contents += new_overlay_types

	UNSETEMPTY(new_overlay_types)
	src.atmos_overlay_types = new_overlay_types

/proc/typecache_of_gases_with_no_overlays()
	. = list()
	for (var/gastype in subtypesof(/datum/gas))
		var/datum/gas/gasvar = gastype
		if (!initial(gasvar.gas_overlay))
			.[gastype] = TRUE

/////////////////////////////SIMULATION///////////////////////////////////
#ifdef TRACK_MAX_SHARE
#define LAST_SHARE_CHECK \
	var/last_share = our_air.last_share;\
	max_share = max(last_share, max_share);\
	if(last_share > MINIMUM_AIR_TO_SUSPEND){\
		our_excited_group.reset_cooldowns();\
	} else if(last_share > MINIMUM_MOLES_DELTA_TO_MOVE) {\
		our_excited_group.dismantle_cooldown = 0;\
		cached_ticker = 0;\
	}
#else
#define LAST_SHARE_CHECK \
	var/last_share = our_air.last_share;\
	if(last_share > MINIMUM_AIR_TO_SUSPEND){\
		our_excited_group.reset_cooldowns();\
	} else if(last_share > MINIMUM_MOLES_DELTA_TO_MOVE) {\
		our_excited_group.dismantle_cooldown = 0;\
		cached_ticker = 0;\
	}
#endif

/turf/proc/process_cell(fire_count)
	SSair.remove_from_active(src)

/turf/open/process_cell(fire_count)
	if(archived_cycle < fire_count) //archive self if not already done
		archive()

	current_cycle = fire_count
	var/cached_ticker = significant_share_ticker
	cached_ticker += 1

	//cache for sanic speed
	var/list/adjacent_turfs = atmos_adjacent_turfs
	var/datum/excited_group/our_excited_group = excited_group
	var/adjacent_turfs_length = LAZYLEN(adjacent_turfs)

	var/datum/gas_mixture/our_air = air

	#ifdef TRACK_MAX_SHARE
	max_share = 0 //Gotta reset our tracker
	#endif

	for(var/t in adjacent_turfs)
		var/turf/open/enemy_tile = t

		if(fire_count <= enemy_tile.current_cycle)
			continue
		enemy_tile.archive()

	/******************* GROUP HANDLING START *****************************************************************/

		var/should_share_air = FALSE
		var/datum/gas_mixture/enemy_air = enemy_tile.air

		//cache for sanic speed
		var/datum/excited_group/enemy_excited_group = enemy_tile.excited_group
		//If we are both in an excited group, and they aren't the same, merge.
		//If we are both in an excited group, and you're active, share
		//If we pass compare or if we're rebuilding, and if we're not already both in a group, lets join up
		//If we both pass compare or are rebuilding, add to active and share
		if(our_excited_group && enemy_excited_group)
			if(our_excited_group != enemy_excited_group)
				//combine groups (this also handles updating the excited_group var of all involved turfs)
				our_excited_group.merge_groups(enemy_excited_group)
				our_excited_group = excited_group //update our cache
		if(our_excited_group && enemy_excited_group && enemy_tile.excited) //If you're both excited, no need to compare right?
			should_share_air = TRUE
		else if(our_air.compare(enemy_air)) //Lets see if you're up for it
			SSair.add_to_active(enemy_tile, FALSE) //Add yourself young man
			var/datum/excited_group/EG = our_excited_group || enemy_excited_group || new
			if(!our_excited_group)
				EG.add_turf(src)
			if(!enemy_excited_group)
				EG.add_turf(enemy_tile)
			our_excited_group = excited_group
			should_share_air = TRUE

		//air sharing
		if(should_share_air)
			var/difference = our_air.share(enemy_air, adjacent_turfs_length)
			if(difference)
				if(difference > 0)
					consider_pressure_difference(enemy_tile, difference)
				else
					enemy_tile.consider_pressure_difference(src, -difference)
			//This acts effectivly as a very slow timer, the max deltas of the group will slowly lower until it breaksdown, they then pop up a bit, and fall back down until irrelevant
			LAST_SHARE_CHECK


	/******************* GROUP HANDLING FINISH *********************************************************************/


	our_air.react(src)

	update_visuals()
	if(CONSIDER_SUPERCONDUCTIVITY(air))
		SSair.active_super_conductivity += src
	else if(!our_excited_group) //If nothing of interest is happening, kill the active turf
		SSair.remove_from_active(src) //This will kill any connected excited group, be careful
	if(cached_ticker > EXCITED_GROUP_DISMANTLE_CYCLES) //If you're stalling out, take a rest
		SSair.remove_from_active(src, FALSE)

	significant_share_ticker = cached_ticker //Save our changes
	temperature_expose(our_air, our_air.temperature) //I should add some sanity checks to this thing

////////////////////Excited Group Cleanup///////////////////////

/turf/open/proc/cleanup_group(fire_count, breakdown, dismantle)
	current_cycle = fire_count + 0.5 //It works, I know it's dumb but it works

	//cache for sanic speed
	var/list/adjacent_turfs = atmos_adjacent_turfs
	var/datum/excited_group/our_excited_group = excited_group

	for(var/t in adjacent_turfs)
		var/turf/open/enemy_tile = t

		if(current_cycle <= enemy_tile.current_cycle)
			continue

		//cache for sanic speed
		var/datum/excited_group/enemy_excited_group = enemy_tile.excited_group
		//If we are both in an excited group, and they aren't the same, merge.
		//Otherwise make/take one to join and get to it
		if(our_excited_group && enemy_excited_group)
			if(our_excited_group != enemy_excited_group)
				//combine groups (this also handles updating the excited_group var of all involved turfs)
				our_excited_group.merge_groups(enemy_excited_group)
				our_excited_group = excited_group //update our cache
		else
			var/datum/excited_group/EG = our_excited_group || enemy_excited_group || new
			if(!our_excited_group)
				EG.add_turf(src)
			if(!enemy_excited_group)
				EG.add_turf(enemy_tile)
			our_excited_group = excited_group
	if(our_excited_group)
		our_excited_group.breakdown_cooldown = breakdown //Update with the old data
		our_excited_group.dismantle_cooldown = dismantle

//////////////////////////SPACEWIND/////////////////////////////

/turf/open/proc/consider_pressure_difference(turf/T, difference)
	SSair.high_pressure_delta |= src
	if(difference > pressure_difference)
		pressure_direction = get_dir(src, T)
		pressure_difference = difference

/turf/open/proc/high_pressure_movements()
	var/atom/movable/M
	for(var/thing in src)
		M = thing
		if (!M.anchored && !M.pulledby && M.last_high_pressure_movement_air_cycle < SSair.times_fired)
			M.experience_pressure_difference(pressure_difference, pressure_direction)

/atom/movable/var/pressure_resistance = 10
/atom/movable/var/last_high_pressure_movement_air_cycle = 0

/atom/movable/proc/experience_pressure_difference(pressure_difference, direction, pressure_resistance_prob_delta = 0)
	var/const/PROBABILITY_OFFSET = 25
	var/const/PROBABILITY_BASE_PRECENT = 75
	var/max_force = sqrt(pressure_difference)*(MOVE_FORCE_DEFAULT / 5)
	set waitfor = FALSE
	var/move_prob = 100
	if (pressure_resistance > 0)
		move_prob = (pressure_difference/pressure_resistance*PROBABILITY_BASE_PRECENT)-PROBABILITY_OFFSET
	move_prob += pressure_resistance_prob_delta
	if (move_prob > PROBABILITY_OFFSET && prob(move_prob) && (move_resist != INFINITY) && (!anchored && (max_force >= (move_resist * MOVE_FORCE_PUSH_RATIO))) || (anchored && (max_force >= (move_resist * MOVE_FORCE_FORCEPUSH_RATIO))))
		step(src, direction)
		last_high_pressure_movement_air_cycle = SSair.times_fired

///////////////////////////EXCITED GROUPS/////////////////////////////

/*
	I've got a problem with excited groups
	Adding tiles works out fine, but if you try and remove them, we get issues
	The main one is to do with how sleeping tiles are processed
	If a tile is sleeping, it is removed from the active turfs list and not processed at all
	The issue comes when we try and reform excited groups after a removal like this
	and the turfs just poof go fully to sleep.
	I'm going to try keeping track of state with the excited variable, and if it's set to sleep, we just well,
	only preform merge operations with neighboring excited groups.

	Maybe this will help with player caused rebuilds
*/
/datum/excited_group
	var/list/turf_list = list()
	var/breakdown_cooldown = 0
	var/dismantle_cooldown = 0
	var/should_display = FALSE
	var/display_id = 0
	var/static/wrapping_id = 0

/datum/excited_group/New()
	SSair.excited_groups += src

/datum/excited_group/proc/add_turf(turf/open/T)
	turf_list += T
	T.excited_group = src
	reset_cooldowns()
	if(should_display || SSair.display_all_groups)
		display_turf(T)

/datum/excited_group/proc/merge_groups(datum/excited_group/E)
	if(turf_list.len > E.turf_list.len)
		SSair.excited_groups -= E
		for(var/t in E.turf_list)
			var/turf/open/T = t
			T.excited_group = src
			turf_list += T
		should_display = E.should_display | should_display
		if(should_display || SSair.display_all_groups)
			E.hide_turfs()
			display_turfs()
		reset_cooldowns()
	else
		SSair.excited_groups -= src
		for(var/t in turf_list)
			var/turf/open/T = t
			T.excited_group = E
			E.turf_list += T
		E.reset_cooldowns()
		E.should_display = E.should_display | should_display
		if(E.should_display || SSair.display_all_groups)
			hide_turfs()
			E.display_turfs()

/datum/excited_group/proc/reset_cooldowns()
	breakdown_cooldown = 0
	dismantle_cooldown = 0

//argument is so world start can clear out any turf differences quickly.
/datum/excited_group/proc/self_breakdown(roundstart = FALSE, poke_turfs = TRUE)
	var/datum/gas_mixture/A = new

	//make local for sanic speed
	var/list/A_gases = A.gases
	var/list/turf_list = src.turf_list
	var/turflen = turf_list.len
	var/imumutable_in_group = FALSE
	var/energy = 0
	var/heat_cap = 0

	for(var/t in turf_list)
		var/turf/open/T = t
		//Cache?
		var/datum/gas_mixture/turf/mix = T.air
		if (roundstart && istype(T.air, /datum/gas_mixture/immutable))
			imumutable_in_group = TRUE
			A.copy_from(T.air) //This had better be immutable young man
			A_gases = A.gases //update the cache
			break
		//"borrowing" this code from merge(), I need to play with the temp portion. Lets expand it out
		//temperature = (giver.temperature * giver_heat_capacity + temperature * self_heat_capacity) / combined_heat_capacity
		var/capacity = mix.heat_capacity()
		energy += mix.temperature * capacity
		heat_cap += capacity

		var/list/giver_gases = mix.gases
		for(var/giver_id in giver_gases)
			ASSERT_GAS(giver_id, A)
			A_gases[giver_id][MOLES] += giver_gases[giver_id][MOLES]

	if(!imumutable_in_group)
		A.temperature = energy / heat_cap
		for(var/id in A_gases)
			A_gases[id][MOLES] /= turflen

	for(var/t in turf_list)
		var/turf/open/T = t
		T.air.copy_from(A)
		T.update_visuals()
		if(!T.excited && poke_turfs) //Because we only activate all these once every breakdown, in event of lag due to this code and slow space + vent things, increase the wait time for breakdowns
			SSair.add_to_active(T, FALSE) //Maybe check molar diff or something? IDK

	if(roundstart)
		var/datum/gas_mixture/cache = new()
		cache.copy_from(A)
		for(var/t in turf_list)
			var/turf/open/T = t
			A.react(T)
			T.update_visuals()
			A.copy_from(cache) //Keep it the same nerd

	breakdown_cooldown = 0

/datum/excited_group/proc/dismantle(starting_up = FALSE)
	if(!starting_up)
		self_breakdown(poke_turfs = FALSE)
	for(var/t in turf_list)
		var/turf/open/T = t
		T.excited = FALSE
		T.excited_group = null
		SSair.active_turfs -= T
		#ifdef VISUALIZE_ACTIVE_TURFS //Use this when you want details about how the turfs are moving, display_all_groups should work for normal operation
		T.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
		#endif
	garbage_collect(FALSE)

/datum/excited_group/proc/garbage_collect(rebuild_excited_groups = TRUE)
	if(display_id) //If we ever did make those changes
		hide_turfs()
	for(var/t in turf_list)
		var/turf/open/T = t
		T.excited_group = null
	//If this fires during active turfs it'll cause a slight removal of active turfs, as they breakdown if they have no excited group
	if(rebuild_excited_groups) //I want my holes to space consistent you hear me?
		//There's still some bugs with cleanup, doesn't fully merge properly, but this'll do for now
		SSair.add_to_cleanup(src) //Poke everybody in the group, just in case
	turf_list.Cut()
	SSair.excited_groups -= src
	if(SSair.currentpart == SSAIR_EXCITEDGROUPS)
		SSair.currentrun -= src

/datum/excited_group/proc/display_turfs()
	if(display_id == 0) //Hasn't been shown before
		wrapping_id = wrapping_id % GLOB.colored_turfs.len
		wrapping_id++ //We do this after because lists index at 1
		display_id = wrapping_id
	for(var/thing in turf_list)
		var/turf/display = thing
		display.vis_contents += GLOB.colored_turfs[display_id]

/datum/excited_group/proc/hide_turfs()
	for(var/thing in turf_list)
		var/turf/display = thing
		display.vis_contents -= GLOB.colored_turfs[display_id]
	display_id = 0

/datum/excited_group/proc/display_turf(turf/thing)
	if(display_id == 0) //Hasn't been shown before
		wrapping_id = wrapping_id % GLOB.colored_turfs.len
		wrapping_id++ //We do this after because lists index at 1
		display_id = wrapping_id
	thing.vis_contents += GLOB.colored_turfs[display_id]

////////////////////////SUPERCONDUCTIVITY/////////////////////////////

/**
ALLLLLLLLLLLLLLLLLLLLRIGHT HERE WE GOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO

We add any active turfs with a potential superconductor into a list
We process that list, look through each potential superconducter
temp_act it
share a portion of the heat to any adjacent tiles depending on a var set by the conductor to define permiability

This contrasts with the old system, which stored temperature on the turf itself, so it would slowly flow between turfs.
This meant that walls/windows could truly "heat up".
It also meant that fires would never settle, as the superconductors would just slowllllly move heat.

My current implementation is not built to support heat leaking through floors, as that is dumb, and would slow shit down a lot
**/

/turf/proc/disperse_directions()
	for(var/direction in GLOB.cardinals)
		if(direction & atmos_open_turfs && !(atmos_supeconductivity & direction))
			. |= direction

/turf/open/proc/conductivity_directions()
	for(var/direction in GLOB.cardinals)
		var/turf/T = get_step(src, direction)
		if(!(T in atmos_adjacent_turfs) && !(atmos_supeconductivity & direction))
			. |= direction

/turf/open/proc/conduct_around()
	if(archived_cycle < SSair.times_fired)
		archive()
	var/conductivity_directions = conductivity_directions()
	if(conductivity_directions)
		//Conduct with tiles around me
		for(var/direction in GLOB.cardinals)
			//If you're totally open I don't want to talk to you
			if(conductivity_directions & direction)
				var/turf/neighbor = get_step(src,direction)

				if(!neighbor.thermal_conductivity)
					continue

				neighbor.super_conduct(air, src)

/turf/proc/super_conduct(datum/gas_mixture/mix, turf/source)
	temperature_expose(null, mix.temperature, null)
	var/disperse_directions = disperse_directions()
	for(var/direction in GLOB.cardinals)
		if(disperse_directions & direction)
			var/turf/open/T = get_step(src,direction)
			if(T == source)
				continue
			if(!CONSIDER_SUPERCONDUCTIVITY(T.air))
				continue
			if(T.archived_cycle < SSair.times_fired)
				T.archive()
			T.air.temperature_share(mix, thermal_conductivity)
			SSair.add_to_active(T, FALSE)

/turf/open/super_conduct(datum/gas_mixture/mix, turf/source)
	if(archived_cycle < SSair.times_fired)
		archive()
	air.temperature_share(mix, WINDOW_HEAT_TRANSFER_COEFFICIENT)
	SSair.add_to_active(src, FALSE)
	..(air)

