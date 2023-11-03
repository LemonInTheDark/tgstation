/datum/ai_behavior/find_potential_targets
	action_cooldown = 2 SECONDS
	/// How many times we have failed to find a target
	/// Effects how long we wait between scans (optimization thing)
	var/found_nothing_count = 0
	/// How far can we see stuff?
	var/vision_range = 9
	/// Blackboard key for aggro range, uses vision range if not specified
	var/aggro_range_key = BB_AGGRO_RANGE
	/// Static typecache list of potentially dangerous objs
	var/static/list/hostile_machines = typecacheof(list(/obj/machinery/porta_turret, /obj/vehicle/sealed/mecha))

/datum/ai_behavior/find_potential_targets/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targetting_datum_key, hiding_location_key)
	. = ..()
	var/mob/living/living_mob = controller.pawn
	var/datum/targetting_datum/targetting_datum = controller.blackboard[targetting_datum_key]

	if(!targetting_datum)
		CRASH("No target datum was supplied in the blackboard for [controller.pawn]")

	var/atom/current_target = controller.blackboard[target_key]
	if (targetting_datum.can_attack(living_mob, current_target, vision_range))
		finish_action(controller, succeeded = FALSE)
		return

	// Every time we try, increment our found nothing count
	found_nothing_count += 1
	// Can get at most 5 times slower then the first delay
	action_cooldown = initial(action_cooldown) * clamp(found_nothing_count, 0, 5)
	var/aggro_range = controller.blackboard[aggro_range_key] || vision_range

	controller.clear_blackboard_key(target_key)

	var/list/potential_targets = hearers(aggro_range, get_turf(controller.pawn)) - living_mob //Remove self, so we don't suicide

	for(var/obj/machinery/enemy_spotted in range(aggro_range, living_mob))
		// Stand down private
		if(!is_type_in_typecache(enemy_spotted, hostile_machines))
			continue
		potential_targets += enemy_spotted

	if(!potential_targets.len)
		finish_action(controller, succeeded = FALSE)
		return

	var/list/filtered_targets = list()
	for(var/atom/pot_target in potential_targets)
		if(!targetting_datum.can_attack(living_mob, pot_target))//Can we attack it?
			continue
		filtered_targets += pot_target

	if(!filtered_targets.len)
		finish_action(controller, succeeded = FALSE)
		return

	// If we find something, set it back down to 0
	found_nothing_count = 0
	action_cooldown = initial(action_cooldown)
	var/atom/target = pick_final_target(controller, filtered_targets)
	controller.set_blackboard_key(target_key, target)

	var/atom/potential_hiding_location = targetting_datum.find_hidden_mobs(living_mob, target)

	if(potential_hiding_location) //If they're hiding inside of something, we need to know so we can go for that instead initially.
		controller.set_blackboard_key(hiding_location_key, potential_hiding_location)

	finish_action(controller, succeeded = TRUE)

/datum/ai_behavior/find_potential_targets/finish_action(datum/ai_controller/controller, succeeded, ...)
	. = ..()
	if (succeeded)
		controller.CancelActions() // On retarget cancel any further queued actions so that they will setup again with new target

/// Returns the desired final target from the filtered list of targets
/datum/ai_behavior/find_potential_targets/proc/pick_final_target(datum/ai_controller/controller, list/filtered_targets)
	return pick(filtered_targets)
