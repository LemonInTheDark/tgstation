/*
AI controllers are a datumized form of AI that simulates the input a player would otherwise give to a atom. What this means is that these datums
have ways of interacting with a specific atom and control it. They posses a blackboard with the information the AI knows and has, and will plan behaviors it will try to execute through
multiple modular subtrees with behaviors
*/

/datum/ai_controller
	///The atom this controller is controlling
	var/atom/pawn
	/**
	 * This is a list of variables the AI uses and can be mutated by actions.
	 *
	 * When an action is performed you pass this list and any relevant keys for the variables it can mutate.
	 *
	 * DO NOT set values in the blackboard directly, and especially not if you're adding a datum reference to this!
	 * Use the setters, this is important for reference handing.
	 */
	var/list/blackboard = list()

	///Bitfield of traits for this AI to handle extra behavior
	var/ai_traits = NONE
	///Current actions planned to be performed by the AI in the upcoming plan
	var/list/planned_behaviors
	///Current actions being performed by the AI -> TRUE
	var/list/current_behaviors = list()
	///Behavior types -> when we want to execute them next
	var/list/behavior_cooldowns = list()
	/// timer ID of the currently queued ai_behavior's callback
	/// Corresponds to the first behavior in the current_behaviors list
	var/currently_queued_id = TIMER_ID_NULL
	/// The behavior we have queued currently
	var/datum/ai_behavior/currently_queued_behavior
	/// How many behaviors we have that demand no planning
	var/no_planning_sources = 0
	///Current status of AI (OFF/ON)
	var/ai_status
	///Current movement target of the AI, generally set by decision making.
	var/atom/current_movement_target
	///Identifier for what last touched our movement target, so it can be cleared conditionally
	var/movement_target_source
	///Stored arguments for behaviors given during their initial creation
	var/list/behavior_args = list()
	///Tracks recent pathing attempts, if we fail too many in a row we fail our current plans.
	var/pathing_attempts
	///Can the AI remain in control if there is a client?
	var/continue_processing_when_client = FALSE
	///distance to give up on target
	var/max_target_distance = 14
	///Cooldown for new plans, to prevent AI from going nuts if it can't think of new plans and looping on end
	COOLDOWN_DECLARE(failed_planning_cooldown)
	///All subtrees this AI has available, will run them in order, so make sure they're in the order you want them to run. On initialization of this type, it will start as a typepath(s) and get converted to references of ai_subtrees found in SSai_controllers when init_subtrees() is called
	var/list/planning_subtrees

	///The idle behavior this AI performs when it has no actions.
	var/datum/idle_behavior/idle_behavior = null

	// Movement related things here
	///Reference to the movement datum we use. Is a type on initialize but becomes a ref afterwards.
	var/datum/ai_movement/ai_movement = /datum/ai_movement/dumb
	///Delay between movements. This is on the controller so we can keep the movement datum singleton
	var/movement_delay = 0.1 SECONDS

	// The variables below are fucking stupid and should be put into the blackboard at some point.
	///AI paused time
	var/paused_until = 0

	/// TRUE if we're able to run, FALSE if we aren't
	/// Should not be set manually, override get_able_to_run() instead
	/// Make sure you hook update_able_to_run() in setup_able_to_run() to whatever parameters changing that you added
	/// Otherwise we will not pay attention to them changing
	var/able_to_run = FALSE

	/// If we have a behavior that wants to fire next tick, we'll do it via process() rather then timers
	/// (lower cost)
	var/fire_on_process = FALSE

/datum/ai_controller/New(atom/new_pawn)
	change_ai_movement_type(ai_movement)
	init_subtrees()

	if(idle_behavior)
		idle_behavior = new idle_behavior()

	if(!isnull(new_pawn)) // unit tests need the ai_controller to exist in isolation due to list schenanigans i hate it here
		PossessPawn(new_pawn)

/datum/ai_controller/Destroy(force, ...)
	set_ai_status(AI_STATUS_OFF)
	UnpossessPawn(FALSE)
	set_movement_target(type, null)
	if(ai_movement.moving_controllers[src])
		ai_movement.stop_moving_towards(src)
	return ..()

///Sets the current movement target, with an optional param to override the movement behavior
/datum/ai_controller/proc/set_movement_target(source, atom/target, datum/ai_movement/new_movement)
	if(current_movement_target)
		UnregisterSignal(current_movement_target, COMSIG_MOVABLE_MOVED)
	movement_target_source = source
	current_movement_target = target
	RegisterSignal(current_movement_target, COMSIG_MOVABLE_MOVED, PROC_REF(check_movement_target))
	check_movement_target()
	if(new_movement)
		change_ai_movement_type(new_movement)

///Checks to see if the movement target is invalid, or if it's satisfied any of our target locked behaviors
/datum/ai_controller/proc/check_movement_target()
	SIGNAL_HANDLER
	if(current_movement_target && !isatom(current_movement_target))
		stack_trace("[pawn]'s current movement target is not an atom, rather a [current_movement_target.type]! Did you accidentally set it to a weakref?")
		CancelActions()
		return

	if(get_dist(pawn, current_movement_target) > max_target_distance) //The distance is out of range
		CancelActions()
		return

	// This is duplicated code from handle_behavior(), but it lets us vaugely safely assert that behaviors do not need to be checked
	// If they are not past their required waiting time, which is v powerful
	for(var/datum/ai_behavior/current_behavior as anything in current_behaviors)
		if(!(current_behavior.behavior_flags & AI_BEHAVIOR_REQUIRE_MOVEMENT))
			continue
		if(!current_movement_target)
			stack_trace("[pawn] wants to perform action type [current_behavior.type] which requires movement, but has no current movement target!")
			return //This can cause issues, so don't let these slide.

		///Stops pawns from performing such actions that should require the target to be adjacent.
		var/atom/movable/moving_pawn = pawn
		if(current_behavior.required_distance >= get_dist(moving_pawn, current_movement_target) && \
			!(current_behavior.behavior_flags & AI_BEHAVIOR_REQUIRE_REACH) || moving_pawn.CanReach(current_movement_target)) ///Are we close enough to engage?

			if(ai_movement.moving_controllers[src] == current_movement_target) //We are close enough, if we're moving stop.
				ai_movement.stop_moving_towards(src)
			continue

		else if(ai_movement.moving_controllers[src] != current_movement_target) //We're too far, if we're not already moving start doing it.
			ai_movement.start_moving_towards(src, current_movement_target, current_behavior.required_distance) //Then start moving

///Overrides the current ai_movement of this controller with a new one
/datum/ai_controller/proc/change_ai_movement_type(datum/ai_movement/new_movement)
	ai_movement = SSai_movement.movement_types[new_movement]

///Completely replaces the planning_subtrees with a new set based on argument provided, list provided must contain specifically typepaths
/datum/ai_controller/proc/replace_planning_subtrees(list/typepaths_of_new_subtrees)
	planning_subtrees = typepaths_of_new_subtrees
	init_subtrees()

///Loops over the subtrees in planning_subtrees and looks at the ai_controllers to grab a reference, ENSURE planning_subtrees ARE TYPEPATHS AND NOT INSTANCES/REFERENCES BEFORE EXECUTING THIS
/datum/ai_controller/proc/init_subtrees()
	if(!length(planning_subtrees))
		return
	var/list/temp_subtree_list = list()
	for(var/subtree in planning_subtrees)
		var/subtree_instance = SSai_controllers.ai_subtrees[subtree]
		temp_subtree_list += subtree_instance
	planning_subtrees = temp_subtree_list

///Proc to move from one pawn to another, this will destroy the target's existing controller.
/datum/ai_controller/proc/PossessPawn(atom/new_pawn)
	SHOULD_CALL_PARENT(TRUE)
	if(pawn) //Reset any old signals
		UnpossessPawn(FALSE)

	if(istype(new_pawn.ai_controller)) //Existing AI, kill it.
		QDEL_NULL(new_pawn.ai_controller)

	if(TryPossessPawn(new_pawn) & AI_CONTROLLER_INCOMPATIBLE)
		qdel(src)
		CRASH("[src] attached to [new_pawn] but these are not compatible!")

	pawn = new_pawn
	pawn.ai_controller = src

	SEND_SIGNAL(src, COMSIG_AI_CONTROLLER_POSSESSED_PAWN)

	reset_ai_status()
	RegisterSignal(pawn, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_changed))
	RegisterSignal(pawn, COMSIG_MOB_LOGIN, PROC_REF(on_sentience_gained))
	RegisterSignal(pawn, COMSIG_MOVABLE_MOVED, PROC_REF(check_movement_target))
	RegisterSignal(pawn, COMSIG_QDELETING, PROC_REF(on_pawn_qdeleted))
	update_able_to_run()
	setup_able_to_run()

/// Sets the AI on or off based on current conditions, call to reset after you've manually disabled it somewhere
/datum/ai_controller/proc/reset_ai_status()
	set_ai_status(get_expected_ai_status())

/// Returns what the AI status should be based on current conditions.
/datum/ai_controller/proc/get_expected_ai_status()
	var/final_status = AI_STATUS_ON

	if (!ismob(pawn))
		return final_status

	var/mob/living/mob_pawn = pawn

	if(!continue_processing_when_client && mob_pawn.client)
		final_status = AI_STATUS_OFF

	if(ai_traits & CAN_ACT_WHILE_DEAD)
		return final_status

	if(mob_pawn.stat == DEAD)
		final_status = AI_STATUS_OFF

	return final_status

///Abstract proc for initializing the pawn to the new controller
/datum/ai_controller/proc/TryPossessPawn(atom/new_pawn)
	return

///Proc for deinitializing the pawn to the old controller
/datum/ai_controller/proc/UnpossessPawn(destroy)
	SHOULD_CALL_PARENT(TRUE)
	if(isnull(pawn))
		return // instantiated without an applicable pawn, fine

	UnregisterSignal(pawn, list(COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT, COMSIG_MOB_STATCHANGE, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	clear_able_to_run()
	if(ai_movement.moving_controllers[src])
		ai_movement.stop_moving_towards(src)
	pawn.ai_controller = null
	pawn = null
	if(destroy)
		qdel(src)

/datum/ai_controller/proc/setup_able_to_run()
	// paused_until is handled by PauseAi() manually
	RegisterSignals(pawn, list(SIGNAL_ADDTRAIT(TRAIT_AI_PAUSED), SIGNAL_REMOVETRAIT(TRAIT_AI_PAUSED)), PROC_REF(update_able_to_run))

/datum/ai_controller/proc/clear_able_to_run()
	UnregisterSignal(pawn, list(SIGNAL_ADDTRAIT(TRAIT_AI_PAUSED), SIGNAL_REMOVETRAIT(TRAIT_AI_PAUSED)))

/datum/ai_controller/proc/update_able_to_run()
	SIGNAL_HANDLER
	able_to_run = get_able_to_run()
	if(!able_to_run)
		SSmove_manager.stop_looping(pawn) //stop moving, since we can't run the controller rn
		if(currently_queued_id != TIMER_ID_NULL)
			deltimer(currently_queued_id, SSai_behaviors)
		currently_queued_id = TIMER_ID_NULL
	else
		if(!length(current_behaviors))
			return
		if(currently_queued_id != TIMER_ID_NULL)
			stack_trace("Tried to restart behaviors but one was already running!")
			return
		decide_on_behavior()

///Returns TRUE if the ai controller can actually run at the moment, FALSE otherwise
/datum/ai_controller/proc/get_able_to_run()
	if(HAS_TRAIT(pawn, TRAIT_AI_PAUSED))
		return FALSE
	if(world.time < paused_until)
		return FALSE
	return TRUE

/// Handles a scheduled ai behavior
/datum/ai_controller/proc/handle_behavior(datum/ai_behavior/current_behavior)
	currently_queued_id = TIMER_ID_NULL
	// Convert the current behaviour action cooldown to realtime seconds from deciseconds.current_behavior
	// Then pick the max of this and the seconds_per_tick passed to ai_controller.process()
	// Action cooldowns cannot happen faster than seconds_per_tick, so seconds_per_tick should be the value used in this scenario.
	var/action_seconds_per_tick = max(current_behavior.get_cooldown(src) * 0.1, world.tick_lag)
	if(!(current_behavior.behavior_flags & AI_BEHAVIOR_REQUIRE_MOVEMENT))
		ProcessBehavior(action_seconds_per_tick, current_behavior)
		return

	if(!current_movement_target)
		stack_trace("[pawn] wants to perform action type [current_behavior.type] which requires movement, but has no current movement target!")
		var/list/arguments = list(src, FALSE)
		var/list/stored_arguments = behavior_args[current_behavior.type]
		if(stored_arguments)
			arguments += stored_arguments
		current_behavior.finish_action(arglist(arguments))
		decide_on_behavior()
		return //This can cause issues, so don't let these slide.
	///Stops pawns from performing such actions that should require the target to be adjacent.
	var/atom/movable/moving_pawn = pawn
	if(current_behavior.required_distance >= get_dist(moving_pawn, current_movement_target) && \
		!(current_behavior.behavior_flags & AI_BEHAVIOR_REQUIRE_REACH) || moving_pawn.CanReach(current_movement_target)) ///Are we close enough to engage?

		if(ai_movement.moving_controllers[src] == current_movement_target) //We are close enough, if we're moving stop.
			ai_movement.stop_moving_towards(src)
		ProcessBehavior(action_seconds_per_tick, current_behavior)
		return

	else if(ai_movement.moving_controllers[src] != current_movement_target) //We're too far, if we're not already moving start doing it.
		ai_movement.start_moving_towards(src, current_movement_target, current_behavior.required_distance) //Then start moving

	if(current_behavior.behavior_flags & AI_BEHAVIOR_MOVE_AND_PERFORM) //If we can move and perform then do so.
		ProcessBehavior(action_seconds_per_tick, current_behavior)
		return

	decide_on_behavior()

///Handles idle behavior, called every ds so it's part of a processing subsystem
/datum/ai_controller/process(seconds_per_tick)
	if(fire_on_process && currently_queued_behavior)
		handle_behavior(currently_queued_behavior)
		return
	if(idle_behavior && !length(current_behaviors))
		idle_behavior.perform_idle_behavior(seconds_per_tick, src) //Do some stupid shit while we have nothing to do
		return

///Determines whether the AI can currently make a new plan
/datum/ai_controller/proc/able_to_plan()
	if(QDELETED(pawn))
		return FALSE
	if(no_planning_sources > 0) //We have a behavior that blocks planning
		return FALSE
	return TRUE

///This is where you decide what actions are taken by the AI.
/datum/ai_controller/proc/SelectBehaviors(seconds_per_tick)
	SHOULD_NOT_SLEEP(TRUE) //Fuck you don't sleep in procs like this.
	if(!COOLDOWN_FINISHED(src, failed_planning_cooldown))
		return FALSE

	var/list/old_planned_behaviors = planned_behaviors
	planned_behaviors = list()

	if(length(planning_subtrees))
		for(var/datum/ai_planning_subtree/subtree as anything in planning_subtrees)
			if(subtree.SelectBehaviors(src, seconds_per_tick) == SUBTREE_RETURN_FINISH_PLANNING)
				break

	/// We reverse this just to avoid constant requeuing
	for(var/datum/ai_behavior/forgotten_behavior as anything in current_behaviors - planned_behaviors)
		var/list/arguments = list(src, FALSE)
		var/list/stored_arguments = behavior_args[forgotten_behavior.type]
		if(stored_arguments)
			arguments += stored_arguments
		forgotten_behavior.finish_action(arglist(arguments))

	SEND_SIGNAL(src, COMSIG_AI_CONTROLLER_PICKED_BEHAVIORS, old_planned_behaviors, planned_behaviors)

///This proc handles changing ai status, and starts/stops processing if required.
/datum/ai_controller/proc/set_ai_status(new_ai_status)
	if(ai_status == new_ai_status)
		return FALSE //no change

	ai_status = new_ai_status
	switch(ai_status)
		if(AI_STATUS_ON)
			SSai_controllers.active_ai_controllers += src
		if(AI_STATUS_OFF)
			SSai_controllers.active_ai_controllers -= src
			CancelActions()

/datum/ai_controller/proc/PauseAi(time)
	paused_until = world.time + time
	update_able_to_run()
	addtimer(CALLBACK(src, PROC_REF(update_able_to_run)), time, timer_subsystem = SSai_behaviors)

// Doesn't work so good, why?
/datum/ai_controller/proc/modify_cooldown(datum/ai_behavior/behavior, new_cooldown)
	if(currently_queued_id != TIMER_ID_NULL)
		deltimer(currently_queued_id)
	behavior_cooldowns[behavior.type] = new_cooldown
	decide_on_behavior()

/// Decides on the behavior to run next, if you find one run it
/datum/ai_controller/proc/decide_on_behavior()
	if(!able_to_run || !length(current_behaviors) || currently_queued_id != TIMER_ID_NULL)
		return

	var/datum/ai_behavior/next_behavior
	var/lowest_delay = INFINITY
	for(var/datum/ai_behavior/potential as anything in current_behaviors)
		var/delay = behavior_cooldowns[potential.type]
		if(delay >= lowest_delay)
			continue
		lowest_delay = delay
		next_behavior = potential
		// If we've found something that wants to run NOW
		// Then it takes priority and runs immediately
		if(lowest_delay <= world.time)
			break

	if(lowest_delay <= world.time + world.tick_lag)
		fire_on_process = TRUE
		START_PROCESSING(SSai_idle, src)
		currently_queued_behavior = next_behavior
		return

	if(fire_on_process)
		STOP_PROCESSING(SSai_idle, src)
		fire_on_process = FALSE
	if(next_behavior)
		var/id = addtimer(CALLBACK(src, PROC_REF(handle_behavior), next_behavior), max(lowest_delay - world.time, world.tick_lag), TIMER_STOPPABLE, timer_subsystem = SSai_behaviors)
		currently_queued_id = id
		currently_queued_behavior = next_behavior
	else
		currently_queued_behavior = null

///Call this to add a behavior to the stack.
/datum/ai_controller/proc/queue_behavior(behavior_type, ...)
	var/datum/ai_behavior/behavior = GET_AI_BEHAVIOR(behavior_type)
	if(!behavior)
		CRASH("Behavior [behavior_type] not found.")
	var/list/arguments = args.Copy()
	arguments[1] = src

	if(current_behaviors[behavior]) ///It's still in the plan, don't add it again to current_behaviors but do keep it in the planned behavior list so its not cancelled
		planned_behaviors[behavior] = TRUE
		return

	if(!behavior.setup(arglist(arguments)))
		return

	var/cooldown
	if(behavior_cooldowns[behavior_type])
		cooldown = behavior_cooldowns[behavior_type]
	else
		cooldown = world.time
		behavior_cooldowns[behavior_type] = cooldown

	var/current_queue_time = -INFINITY
	if(currently_queued_behavior)
		current_queue_time = behavior_cooldowns[currently_queued_behavior.type]
 	// If we were on idle and we are no longer, then stop yeah?
	if(!length(current_behaviors) && able_to_run)
		STOP_PROCESSING(SSai_idle, src)
		// First behavior gets a timer, none else
		var/id = addtimer(CALLBACK(src, PROC_REF(handle_behavior), behavior), max(cooldown - world.time, world.tick_lag), TIMER_STOPPABLE, timer_subsystem = SSai_behaviors)
		currently_queued_id = id
		currently_queued_behavior = behavior
	// If we queue with a delay lower then anything else (and everything else is delayed) then we can safely queue
	else if(cooldown < current_queue_time && current_queue_time >= world.time && able_to_run)
		if(currently_queued_id != TIMER_ID_NULL)
			deltimer(currently_queued_id, SSai_behaviors)
		var/id = addtimer(CALLBACK(src, PROC_REF(handle_behavior), behavior), max(cooldown - world.time, world.tick_lag), TIMER_STOPPABLE, timer_subsystem = SSai_behaviors)
		currently_queued_id = id
		currently_queued_behavior = behavior
	// Implied, if we're trying to run then we go based off insert order, and we'd always lose anyway

	if(!(behavior.behavior_flags & AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION))
		no_planning_sources += 1

	current_behaviors[behavior] = TRUE
	planned_behaviors[behavior] = TRUE
	arguments.Cut(1, 2)
	if(length(arguments))
		behavior_args[behavior_type] = arguments
	else
		behavior_args -= behavior_type
	SEND_SIGNAL(src, AI_CONTROLLER_BEHAVIOR_QUEUED(behavior_type), arguments)

/datum/ai_controller/proc/ProcessBehavior(seconds_per_tick, datum/ai_behavior/behavior)
	var/list/arguments = list(seconds_per_tick, src)
	var/list/stored_arguments = behavior_args[behavior.type]
	if(stored_arguments)
		arguments += stored_arguments

	var/process_flags = behavior.perform(arglist(arguments))
	if(process_flags & AI_BEHAVIOR_DELAY)
		behavior_cooldowns[behavior.type] = world.time + behavior.get_cooldown(src)
	if(process_flags & AI_BEHAVIOR_FAILED)
		arguments[1] = src
		arguments[2] = FALSE
		behavior.finish_action(arglist(arguments))
	else if (process_flags & AI_BEHAVIOR_SUCCEEDED)
		arguments[1] = src
		arguments[2] = TRUE
		behavior.finish_action(arglist(arguments))
	else
		currently_queued_id = TIMER_ID_NULL
		decide_on_behavior()

/datum/ai_controller/proc/CancelActions()
	if(!length(current_behaviors))
		return
	// Reverse to avoid constantly rescheduling timers
	for(var/datum/ai_behavior/current_behavior as anything in current_behaviors)
		var/list/arguments = list(src, FALSE)
		var/list/stored_arguments = behavior_args[current_behavior.type]
		if(stored_arguments)
			arguments += stored_arguments
		current_behavior.finish_action(arglist(arguments))

/// Turn the controller on or off based on if you're alive, we only register to this if the flag is present so don't need to check again
/datum/ai_controller/proc/on_stat_changed(mob/living/source, new_stat)
	SIGNAL_HANDLER
	reset_ai_status()

/datum/ai_controller/proc/on_sentience_gained()
	SIGNAL_HANDLER
	UnregisterSignal(pawn, COMSIG_MOB_LOGIN)
	if(!continue_processing_when_client)
		set_ai_status(AI_STATUS_OFF) //Can't do anything while player is connected
	RegisterSignal(pawn, COMSIG_MOB_LOGOUT, PROC_REF(on_sentience_lost))

/datum/ai_controller/proc/on_sentience_lost()
	SIGNAL_HANDLER
	UnregisterSignal(pawn, COMSIG_MOB_LOGOUT)
	set_ai_status(AI_STATUS_ON) //Can't do anything while player is connected
	RegisterSignal(pawn, COMSIG_MOB_LOGIN, PROC_REF(on_sentience_gained))

// Turn the controller off if the pawn has been qdeleted
/datum/ai_controller/proc/on_pawn_qdeleted()
	SIGNAL_HANDLER
	set_ai_status(AI_STATUS_OFF)
	set_movement_target(type, null)
	if(ai_movement.moving_controllers[src])
		ai_movement.stop_moving_towards(src)

/// Use this proc to define how your controller defines what access the pawn has for the sake of pathfinding. Return the access list you want to use
/datum/ai_controller/proc/get_access()
	return

///Returns the minimum required distance to preform one of our current behaviors. Honestly this should just be cached or something but fuck you
/datum/ai_controller/proc/get_minimum_distance()
	var/minimum_distance = max_target_distance
	// right now I'm just taking the shortest minimum distance of our current behaviors, at some point in the future
	// we should let whatever sets the current_movement_target also set the min distance and max path length
	// (or at least cache it on the controller)
	for(var/datum/ai_behavior/iter_behavior as anything in current_behaviors)
		if(iter_behavior.required_distance < minimum_distance)
			minimum_distance = iter_behavior.required_distance
	return minimum_distance

/// Returns true if we have a blackboard key with the provided key and it is not qdeleting
/datum/ai_controller/proc/blackboard_key_exists(key)
	var/datum/key_value = blackboard[key]
	if (isdatum(key_value))
		return !QDELETED(key_value)
	if (islist(key_value))
		return length(key_value) > 0
	return !!key_value

/**
 * Used to manage references to datum by AI controllers
 *
 * * tracked_datum - something being added to an ai blackboard
 * * key - the associated key
 */
#define TRACK_AI_DATUM_TARGET(tracked_datum, key) do { \
	if(isweakref(tracked_datum)) { \
		var/datum/weakref/_bad_weakref = tracked_datum; \
		stack_trace("Weakref (Actual datum: [_bad_weakref.resolve()]) found in ai datum blackboard! \
			This is an outdated method of ai reference handling, please remove it."); \
	} \
	else if(isdatum(tracked_datum)) { \
		var/datum/_tracked_datum = tracked_datum; \
		if(!HAS_TRAIT_FROM(_tracked_datum, TRAIT_AI_TRACKING, "[REF(src)]_[key]")) { \
			RegisterSignal(_tracked_datum, COMSIG_QDELETING, PROC_REF(sig_remove_from_blackboard), override = TRUE); \
			ADD_TRAIT(_tracked_datum, TRAIT_AI_TRACKING, "[REF(src)]_[key]"); \
		} \
	} \
} while(FALSE)

/**
 * Used to clear previously set reference handing by AI controllers
 *
 * * tracked_datum - something being removed from an ai blackboard
 * * key - the associated key
 */
#define CLEAR_AI_DATUM_TARGET(tracked_datum, key) do { \
	if(isdatum(tracked_datum)) { \
		var/datum/_tracked_datum = tracked_datum; \
		REMOVE_TRAIT(_tracked_datum, TRAIT_AI_TRACKING, "[REF(src)]_[key]"); \
		if(!HAS_TRAIT(_tracked_datum, TRAIT_AI_TRACKING)) { \
			UnregisterSignal(_tracked_datum, COMSIG_QDELETING); \
		} \
	} else if (islist(tracked_datum)) { \
		/* Intentional type filter here */ \
		for(var/datum/_tracked_datum in tracked_datum) { \
			REMOVE_TRAIT(_tracked_datum, TRAIT_AI_TRACKING, "[REF(src)]_[key]"); \
			if(!HAS_TRAIT(_tracked_datum, TRAIT_AI_TRACKING)) { \
				UnregisterSignal(_tracked_datum, COMSIG_QDELETING); \
			} \
		} \
	} \
} while(FALSE)

/// Used for above to track all the keys that have registered a signal
#define TRAIT_AI_TRACKING "tracked_by_ai"

/**
 * Sets the key to the passed "thing".
 *
 * * key - A blackboard key
 * * thing - a value to set the blackboard key to.
 */
/datum/ai_controller/proc/set_blackboard_key(key, thing)
	// Assume it is an error when trying to set a value overtop a list
	if(islist(blackboard[key]))
		CRASH("set_blackboard_key attempting to set a blackboard value to key [key] when it's a list!")
	// Don't do anything if it's already got this value
	if (blackboard[key] == thing)
		return

	// Clear existing values
	if(!isnull(blackboard[key]))
		clear_blackboard_key(key)

	TRACK_AI_DATUM_TARGET(thing, key)
	blackboard[key] = thing
	post_blackboard_key_set(key)

/**
 * Sets the key at index thing to the passed value
 *
 * Assumes the key value is already a list, if not throws an error.
 *
 * * key - A blackboard key, with its value set to a list
 * * thing - a value which becomes the inner list value's key
 * * value - what to set the inner list's value to
 */
/datum/ai_controller/proc/set_blackboard_key_assoc(key, thing, value)
	if(!islist(blackboard[key]))
		CRASH("set_blackboard_key_assoc called on non-list key [key]!")
	// Don't do anything if it's already got this value
	if (blackboard[key][thing] == value)
		return

	TRACK_AI_DATUM_TARGET(thing, key)
	TRACK_AI_DATUM_TARGET(value, key)
	blackboard[key][thing] = value
	post_blackboard_key_set(key)

/**
 * Similar to [proc/set_blackboard_key_assoc] but operates under the assumption the key is a lazylist (so it will create a list)
 * More dangerous / easier to override values, only use when you want to use a lazylist
 *
 * * key - A blackboard key, with its value set to a list
 * * thing - a value which becomes the inner list value's key
 * * value - what to set the inner list's value to
 */
/datum/ai_controller/proc/set_blackboard_key_assoc_lazylist(key, thing, value)
	LAZYINITLIST(blackboard[key])
	// Don't do anything if it's already got this value
	if (blackboard[key][thing] == value)
		return

	TRACK_AI_DATUM_TARGET(thing, key)
	TRACK_AI_DATUM_TARGET(value, key)
	blackboard[key][thing] = value
	post_blackboard_key_set(key)

/**
 * Called after we set a blackboard key, forwards signal information.
 */
/datum/ai_controller/proc/post_blackboard_key_set(key)
	if (isnull(pawn))
		return
	SEND_SIGNAL(pawn, COMSIG_AI_BLACKBOARD_KEY_SET(key))

/**
 * Adds the passed "thing" to the associated key
 *
 * Works with lists or numbers, but not lazylists.
 *
 * * key - A blackboard key
 * * thing - a value to set the blackboard key to.
 */
/datum/ai_controller/proc/add_blackboard_key(key, thing)
	TRACK_AI_DATUM_TARGET(thing, key)
	blackboard[key] += thing

/**
 * Similar to [proc/add_blackboard_key], but performs an insertion rather than an add
 * Throws an error if the key is not a list already, intended only for use with lists
 *
 * * key - A blackboard key, with its value set to a list
 * * thing - a value to set the blackboard key to.
 */
/datum/ai_controller/proc/insert_blackboard_key(key, thing)
	if(!islist(blackboard[key]))
		CRASH("insert_blackboard_key called on non-list key [key]!")
	TRACK_AI_DATUM_TARGET(thing, key)
	blackboard[key] |= thing

/**
 * Adds the passed "thing" to the associated key, assuming key is intended to be a lazylist (so it will create a list)
 * More dangerous / easier to override values, only use when you want to use a lazylist
 *
 * * key - A blackboard key
 * * thing - a value to set the blackboard key to.
 */
/datum/ai_controller/proc/add_blackboard_key_lazylist(key, thing)
	LAZYINITLIST(blackboard[key])
	TRACK_AI_DATUM_TARGET(thing, key)
	blackboard[key] += thing

/**
 * Similar to [proc/insert_blackboard_key_lazylist], but performs an insertion / or rather than an add
 *
 * * key - A blackboard key
 * * thing - a value to set the blackboard key to.
 */
/datum/ai_controller/proc/insert_blackboard_key_lazylist(key, thing)
	LAZYINITLIST(blackboard[key])
	TRACK_AI_DATUM_TARGET(thing, key)
	blackboard[key] |= thing

/**
 * Adds the value to the inner list at key with the inner key set to "thing"
 * Throws an error if the key is not a list already, intended only for use with lists
 *
 * * key - A blackboard key, with its value set to a list
 * * thing - a value which becomes the inner list value's key
 * * value - what to set the inner list's value to
 */
/datum/ai_controller/proc/add_blackboard_key_assoc(key, thing, value)
	if(!islist(blackboard[key]))
		CRASH("add_blackboard_key_assoc called on non-list key [key]!")
	TRACK_AI_DATUM_TARGET(thing, key)
	TRACK_AI_DATUM_TARGET(value, key)
	blackboard[key][thing] += value


/**
 * Similar to [proc/add_blackboard_key_assoc], assuming key is intended to be a lazylist (so it will create a list)
 * More dangerous / easier to override values, only use when you want to use a lazylist
 *
 * * key - A blackboard key, with its value set to a list
 * * thing - a value which becomes the inner list value's key
 * * value - what to set the inner list's value to
 */
/datum/ai_controller/proc/add_blackboard_key_assoc_lazylist(key, thing, value)
	LAZYINITLIST(blackboard[key])
	TRACK_AI_DATUM_TARGET(thing, key)
	TRACK_AI_DATUM_TARGET(value, key)
	blackboard[key][thing] += value

/**
 * Clears the passed key, resetting it to null
 *
 * Not intended for use with list keys - use [proc/remove_thing_from_blackboard_key] if you are removing a value from a list at a key
 *
 * * key - A blackboard key
 */
/datum/ai_controller/proc/clear_blackboard_key(key)
	if(isnull(blackboard[key]))
		return

	CLEAR_AI_DATUM_TARGET(blackboard[key], key)
	blackboard[key] = null
	if(isnull(pawn))
		return
	SEND_SIGNAL(pawn, COMSIG_AI_BLACKBOARD_KEY_CLEARED(key))

/**
 * Remove the passed thing from the associated blackboard key
 *
 * Intended for use with lists, if you're just clearing a reference from a key use [proc/clear_blackboard_key]
 *
 * * key - A blackboard key
 * * thing - a value to set the blackboard key to.
 */
/datum/ai_controller/proc/remove_thing_from_blackboard_key(key, thing)
	var/associated_value = blackboard[key]
	if(thing == associated_value)
		stack_trace("remove_thing_from_blackboard_key was called un-necessarily in a situation where clear_blackboard_key would suffice. ")
		clear_blackboard_key(key)
		return

	if(!islist(associated_value))
		CRASH("remove_thing_from_blackboard_key called with an invalid \"thing\" argument ([thing]). \
			(The associated value of the passed key is not a list and is also not the passed thing, meaning it is clearing an unintended value.)")

	for(var/inner_key in associated_value)
		if(inner_key == thing)
			// flat list
			CLEAR_AI_DATUM_TARGET(thing, key)
			associated_value -= thing
			return
		else if(associated_value[inner_key] == thing)
			// assoc list
			CLEAR_AI_DATUM_TARGET(thing, key)
			associated_value -= inner_key
			return

	CRASH("remove_thing_from_blackboard_key called with an invalid \"thing\" argument ([thing]). \
		(The passed value is not tracked in the passed list.)")

/// Signal proc to go through every key and remove the datum from all keys it finds
/datum/ai_controller/proc/sig_remove_from_blackboard(datum/source)
	SIGNAL_HANDLER

	var/list/list/remove_queue = list(blackboard)
	var/index = 1
	while(index <= length(remove_queue))
		var/list/next_to_clear = remove_queue[index]
		for(var/inner_value in next_to_clear)
			var/associated_value = next_to_clear[inner_value]
			// We are a lists of lists, add the next value to the queue so we can handle references in there
			// (But we only need to bother checking the list if it's not empty.)
			if(islist(inner_value) && length(inner_value))
				UNTYPED_LIST_ADD(remove_queue, inner_value)

			// We found the value that's been deleted. Clear it out from this list
			else if(inner_value == source)
				next_to_clear -= inner_value

			// We are an assoc lists of lists, the list at the next value so we can handle references in there
			// (But again, we only need to bother checking the list if it's not empty.)
			if(islist(associated_value) && length(associated_value))
				UNTYPED_LIST_ADD(remove_queue, associated_value)

			// We found the value that's been deleted, it was an assoc value. Clear it out entirely
			else if(associated_value == source)
				next_to_clear -= inner_value
				SEND_SIGNAL(pawn, COMSIG_AI_BLACKBOARD_KEY_CLEARED(inner_value))

		index += 1

#undef TRACK_AI_DATUM_TARGET
#undef CLEAR_AI_DATUM_TARGET
#undef TRAIT_AI_TRACKING
