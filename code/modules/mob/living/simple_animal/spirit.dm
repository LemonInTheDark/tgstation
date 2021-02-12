/mob/living/simple_animal/spirit
	name = "Spirit"
	real_name = "Spirit"
	desc = "A trickster spirit, what's it doing here?"
	gender = PLURAL
	icon = 'icons/mob/corrupted_spirit.dmi'
	icon_state = "spirit"
	icon_living = "spirit"
	mob_biotypes = MOB_SPIRIT
	incorporeal_move = INCORPOREAL_MOVE_BASIC
	invisibility = INVISIBILITY_SPIRIT
	see_invisible = INVISIBILITY_SPIRIT
	layer = GHOST_LAYER
	healable = FALSE
	sight = SEE_SELF|SEE_TURFS|SEE_MOBS|SEE_OBJS
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
	wander = FALSE
	density = FALSE
	movement_type = FLYING
	move_resist = MOVE_FORCE_OVERPOWERING
	mob_size = MOB_SIZE_TINY
	pass_flags = PASSTABLE | PASSGRILLE | PASSMOB
	stop_automated_movement = TRUE
	status_flags = NONE
	del_on_death = TRUE
	speed = 10
	maxHealth = 10
	health = 10
	healable = FALSE
	speak_emote = list("howls")
	emote_hear = list("screams.")
	response_help_continuous = "grasps at"
	response_help_simple = "grasp at"
	response_disarm_continuous = "falls into"
	response_disarm_simple = "fall into"
	response_harm_continuous = "brushs"
	response_harm_simple = "brush"
	attack_verb_continuous = "screaches"
	attack_verb_simple = "emmits a screach"
	throwforce = 0
	see_in_dark = MAX_RELEVANT_SEE_IN_DARK
	unsuitable_atmos_damage = 0
	damage_coeff = list(BRUTE = 0, BURN = 0, TOX = 0, CLONE = 0, STAMINA = 0, OXY = 0)
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	harm_intent_damage = 0
	friendly_verb_continuous = "brushes"
	friendly_verb_simple = "brush"
	minbodytemp = 0
	maxbodytemp = INFINITY
	held_items = list(null, null)
	dextrous = TRUE
	dextrous_hud_type = /datum/hud/dextrous

	light_system = MOVABLE_LIGHT
	light_range = 2
	light_power = 1
	light_color = COLOR_VIBRANT_LIME
	light_on = FALSE
	light_flags = NONE
	var/contaminated = FALSE

/mob/living/simple_animal/spirit/Initialize()
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_MOB_ATTACK_RANGED, .proc/on_ranged_attack)
	RegisterSignal(src, COMSIG_ATOM_RAD_CONTAMINATING,  .proc/on_contaiminate)

/mob/living/simple_animal/spirit/attackby(obj/item/O, mob/user, params)
	if(!istype(O, /obj/item/ectoattractor))
		return
	var/obj/projectile/ectoplasam/fuck_you = new(get_turf(loc))
	fuck_you.set_homing_target(user)
	fuck_you.firer = src
	fuck_you.fire()
	Move(get_step(src, get_dir(src, user)), get_dir(src, user))
	if(contaminated) //Take damage
		adjustFireLoss(1)
	. = ..()

/mob/living/simple_animal/spirit/process(delta_time)
	for(var/mob/living/target in range(1, src))
		if(target == src)
			continue
		var/chance = 50
		var/dist = get_dist_euclidian(src)
		if(dist <= 1) //If you were close enough in the first place
			if(dist > 0) //If you're not on my tile
				chance = 25 //Should be 25 if we're adjacent
		else	
			chance = 0
		var/multiplier = (DT_PROB(chance, delta_time)) ? 2 : 1

		target.adjustFireLoss(1 * multiplier)
		to_chat(target, "<span class='userdanger'>You feel a slimey heat on your skin, it burns!</span>")

/mob/living/simple_animal/spirit/bullet_act(obj/projectile/shot_me)
	return FALSE

/mob/living/simple_animal/spirit/proc/on_ranged_attack(datum/source, atom/target)
	target.attack_tk(src, TRUE)

/mob/living/simple_animal/spirit/proc/on_contaiminate(datum/source, strength)
	. |= COMPONENT_BLOCK_CONTAMINATION
	if(strength > 50) //Some significant amount of rads
		contaminated = TRUE
		set_light_on(TRUE)
		START_PROCESSING(SSprocessing, src)

/mob/living/simple_animal/spirit/canUseTopic(atom/movable/M, be_close=FALSE, no_dexterity=FALSE, no_tk=FALSE)
	return FALSE

/mob/living/simple_animal/spirit/can_hold_items()
	return FALSE

/mob/living/simple_animal/spirit/UnarmedAttack(atom/A, proximity)
	return FALSE
