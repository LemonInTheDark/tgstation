/mob/living/basic/jps_tester
	ai_controller = /datum/ai_controller/jps_tester
	icon = 'icons/obj/mining.dmi'
	icon_state = "Jaunter"

/datum/ai_controller/jps_tester
	planning_subtrees = list(/datum/ai_planning_subtree/jps_tester)
	ai_movement = /datum/ai_movement/jps

/datum/ai_planning_subtree/jps_tester

/datum/ai_planning_subtree/jps_tester/SelectBehaviors(datum/ai_controller/dog/controller, delta_time)
	controller.set_movement_target(get_step(controller.pawn, EAST))
	controller.queue_behavior(/datum/ai_behavior/move_test)


/datum/ai_behavior/move_test
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0

/datum/ai_behavior/move_test/perform(delta_time, datum/ai_controller/controller)
	finish_action(controller, TRUE)
