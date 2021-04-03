//This element facilitates reaction to atmos changes when a tile is inactive.
//It adds the object to a list on SSair to be processed for so long as the object wants to be processed
//And removes it as soon as the object is no longer interested
//Don't put it on things that tend to clump into one spot, you will cause lag spikes.
/datum/element/atmos_sensitive
	element_flags = ELEMENT_DETACH

/datum/element/atmos_sensitive/Attach(datum/target, mapload = TRUE)
	if(!isatom(target)) //How
		return ELEMENT_INCOMPATIBLE
	var/atom/to_track = target

	RegisterSignal(to_track, COMSIG_MOVABLE_MOVED, .proc/handle_move)
	RegisterSignal(to_track, COMSIG_REMOVE_ATMOS_ATOM, .proc/handle_atmos_end)
	RegisterSignal(to_track, COMSIG_ADD_ATMOS_ATOM, .proc/handle_atmos_start)

	if(!isopenturf(to_track.loc))
		return ..()

	var/turf/open/our_turf = to_track.loc
	to_track.RegisterSignal(our_turf, COMSIG_TURF_EXPOSE, /atom/proc/check_atmos_process)
	if(!mapload) //We assume people aren't putting things in situations that would cause action with no changes
		to_track.check_atmos_process(our_turf, our_turf.air, our_turf.air.temperature)

	return ..()

/datum/element/atmos_sensitive/Detach(datum/source, force)
	var/atom/us = source
	us.UnregisterSignal(us.loc, COMSIG_TURF_EXPOSE)
	if(us.flags_1 & ATMOS_IS_PROCESSING_1)
		SEND_SIGNAL(us, COMSIG_REMOVE_ATMOS_ATOM, us.loc)
	return ..()

/datum/element/atmos_sensitive/proc/handle_atmos_start(atom/source, atom/triggeredby)
	if(source.flags_1 & ATMOS_IS_PROCESSING_1)
		return
	source.flags_1 |= ATMOS_IS_PROCESSING_1
	source.atmos_start()

/datum/element/atmos_sensitive/proc/handle_atmos_end(atom/source, atom/triggeredby)
	if(!source.flags_1 & ATMOS_IS_PROCESSING_1)
		return
	source.flags_1 &= ~ATMOS_IS_PROCESSING_1
	source.atmos_end()

/datum/element/atmos_sensitive/proc/handle_move(datum/source, atom/movable/oldloc, direction, forced)
	var/atom/microchipped_lad = source
	microchipped_lad.UnregisterSignal(oldloc, COMSIG_TURF_EXPOSE)
	if(!isopenturf(microchipped_lad.loc))
		return
	var/turf/open/new_spot = microchipped_lad.loc
	microchipped_lad.RegisterSignal(new_spot, COMSIG_TURF_EXPOSE, /atom/proc/check_atmos_process)
	microchipped_lad.check_atmos_process(new_spot, new_spot.air, new_spot.temperature) //Make sure you're properly registered

/datum/element/atmos_sensitive_advanced
	element_flags = ELEMENT_DETACH

/datum/element/atmos_sensitive_advanced/Attach(datum/target, mapload = TRUE)
	if(!isatom(target)) //How
		return ELEMENT_INCOMPATIBLE
	var/atom/to_track = target

	RegisterSignal(to_track, COMSIG_MOVABLE_PRE_MOVE, .proc/handle_pre_move)
	RegisterSignal(to_track, COMSIG_MOVABLE_MOVED, .proc/handle_move)
	RegisterSignal(to_track, COMSIG_REMOVE_ATMOS_ATOM, .proc/handle_atmos_end)
	RegisterSignal(to_track, COMSIG_ADD_ATMOS_ATOM, .proc/handle_atmos_start)
	to_track.RegisterSignal(to_track, SIGNAL_REMOVETRAIT(ATMOS_PROCESSING), /atom/proc/atmos_end)
	to_track.RegisterSignal(to_track, SIGNAL_ADDTRAIT(ATMOS_PROCESSING), /atom/proc/atmos_start)

	for(var/turf/open/listening in to_track.get_atmos_listening_targets())
		to_track.RegisterSignal(listening, COMSIG_TURF_EXPOSE, /atom/proc/check_atmos_process)
		if(!mapload) //We assume people aren't putting things in situations that would cause action with no changes
			to_track.check_atmos_process(listening, listening.air, listening.air.temperature)

	return ..()

/datum/element/atmos_sensitive_advanced/Detach(datum/source, force)
	var/atom/us = source
	for(var/turf/open/listening as anything in us.get_atmos_listening_targets())
		us.UnregisterSignal(listening, COMSIG_TURF_EXPOSE)
	if(HAS_TRAIT(us, ATMOS_PROCESSING))
		REMOVE_TRAIT(us, ATMOS_PROCESSING, null) //Remove em all
	return ..()

/datum/element/atmos_sensitive_advanced/proc/handle_atmos_start(atom/source, atom/triggeredby)
	var/id = REF(triggeredby)
	if(HAS_TRAIT_FROM(src, ATMOS_PROCESSING, id))
		return
	ADD_TRAIT(src, ATMOS_PROCESSING, id)

/datum/element/atmos_sensitive_advanced/proc/handle_atmos_end(datum/source, atom/triggeredby)
	var/id = REF(triggeredby)
	if(!HAS_TRAIT_FROM(src, ATMOS_PROCESSING, id))
		return
	REMOVE_TRAIT(src, ATMOS_PROCESSING, id)

///Remove all our old listening targets
/datum/element/atmos_sensitive_advanced/proc/handle_pre_move(datum/source, atom/newloc)
	var/atom/atom_source = source
	for(var/turf/open/listening as anything in atom_source.get_atmos_listening_targets())
		atom_source.UnregisterSignal(listening, COMSIG_TURF_EXPOSE)

///Add new listening targets
/datum/element/atmos_sensitive_advanced/proc/handle_move(datum/source, atom/movable/oldloc, direction, forced)
	var/atom/microchipped_lad = source
	for(var/turf/open/new_spot in microchipped_lad.get_atmos_listening_targets())
		microchipped_lad.RegisterSignal(new_spot, COMSIG_TURF_EXPOSE, /atom/proc/check_atmos_process)
		microchipped_lad.check_atmos_process(new_spot, new_spot.air, new_spot.air.temperature) //Make sure you're properly registered

///If we pass our tests, enter us into the ssair queue. If we don't, remove us from the group
/atom/proc/check_atmos_process(datum/source, datum/gas_mixture/air, exposed_temperature)
	if(should_atmos_process(air, exposed_temperature))
		SEND_SIGNAL(src, COMSIG_ADD_ATMOS_ATOM, source)
	else
		SEND_SIGNAL(src, COMSIG_REMOVE_ATMOS_ATOM, source)

/turf/check_atmos_process(datum/source, datum/gas_mixture/air, exposed_temperature)
	if(should_atmos_process(air, exposed_temperature))
		if(flags_1 & ATMOS_IS_PROCESSING_1)
			return
		flags_1 |= ATMOS_IS_PROCESSING_1
		atmos_start(src)
	else if(flags_1 & ATMOS_IS_PROCESSING_1)
		flags_1 &= ~ATMOS_IS_PROCESSING_1
		atmos_end(src)

/atom/proc/process_exposure(turf/open/context)
	//Things can change without a tile becoming active
	if(!istype(context, /turf/open) || !should_atmos_process(context.air, context.air.temperature))
		//If you end up in a locker or a wall reconsider your life decisions
		SEND_SIGNAL(src, COMSIG_REMOVE_ATMOS_ATOM, context)
		return
	atmos_expose(context.air, context.air.temperature)

/turf/open/process_exposure(area/context)
	if(!should_atmos_process(air, air.temperature))
		flags_1 &= ~ATMOS_IS_PROCESSING_1
		atmos_end(src)
		return
	atmos_expose(air, air.temperature)

///We use this proc to check if we should start processing an item, or continue processing it. Returns true/false as expected
/atom/proc/should_atmos_process(datum/gas_mixture/air, exposed_temperature)
	return FALSE

///This is your process() proc
/atom/proc/atmos_expose(datum/gas_mixture/air, exposed_temperature)
	return

/atom/proc/atmos_start(datum/source)
	SHOULD_CALL_PARENT(TRUE)
	SSair.atom_process += src

///Cleanup for our requirements not being met
/atom/proc/atmos_end(datum/source)
	SHOULD_CALL_PARENT(TRUE)
	SSair.atom_process -= src

///Returns a list of potential turfs to listen to based off our current position
///The return value shouldn't change if the thing's location doesn't change
/atom/proc/get_atmos_listening_targets()
	return list(loc)

