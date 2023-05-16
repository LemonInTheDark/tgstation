// Generic one for dismembering limbs
/datum/attack_style/unarmed/generic_damage/mob_attack/dismembers
	can_dismember_limbs = TRUE

/datum/attack_style/unarmed/generic_damage/mob_attack/glomp
	default_attack_verb = "glomp"
	wound_bonus = CANT_WOUND

/datum/attack_style/unarmed/generic_damage/mob_attack/glomp/select_damage(mob/living/simple_animal/slime/attacker, mob/living/smacked, obj/item/bodypart/hitting_with)
	. = ..()
	if(attacker.is_adult)
		. *= 1.5
	if(issilicon(smacked))
		. *= 0.5

/datum/attack_style/unarmed/generic_damage/mob_attack/glomp/finalize_attack(mob/living/simple_animal/slime/attacker, mob/living/smacked, obj/item/weapon, right_clicking)
	if(istype(attacker) && attacker.buckled)
		// can't attack while eating!
		if(attacker in smacked.buckled_mobs)
			attacker.Feedstop()
		return ATTACK_STYLE_SKIPPED

	if(isAI(smacked))
		// AIs are immune to slime glomps
		return ATTACK_STYLE_CANCEL

	return ..()

/datum/attack_style/unarmed/generic_damage/mob_attack/glomp/actually_apply_damage(
	mob/living/simple_animal/slime/attacker,
	mob/living/smacked,
	obj/item/bodypart/hitting_with,
	damage,
	obj/item/bodypart/affecting,
	armor_block,
	direction,
)
	. = ..()

	if(isslime(smacked))
		steal_slime_stuff(attacker, smacked, damage)
		return . + "(stealing nutrition and health)"

	var/slime_power = attacker.powerlevel
	if(slime_power <= 0)
		return .

	var/stunprob = slime_power * 7 + 10  // 17 at level 1, 80 at level 10
	if(!prob(stunprob))
		return .

	do_sparks(5, TRUE, smacked)
	attacker.powerlevel = max(attacker.powerlevel - 3, 0)
	slime_power = attacker.powerlevel
	var/effect_power = slime_power + rand(0, 3)

	smacked.visible_message(span_danger("[attacker] shocks [smacked]!"), ignored_mobs = list(attacker, smacked))
	to_chat(smacked, span_userdanger("[attacker] shocks you, stunning you!"))
	to_chat(smacked, span_notice("You shock [smacked], stunning [smacked.p_them()]!"))

	if(issilicon(smacked))
		smacked.flash_act(affect_slicon = TRUE)
	else
		smacked.Paralyze(effect_power * 2 SECONDS)
		smacked.set_stutter_if_lower(effect_power * 2 SECONDS)

	if (prob(stunprob) && slime_power >= 8)
		// Bonus fire damage
		smacked.adjustFireLoss(effect_power * rand(3, 5))

	return . + "(applying slime stun for [effect_power * 2] seconds)"

/datum/attack_style/unarmed/generic_damage/mob_attack/glomp/proc/steal_slime_stuff(
	mob/living/simple_animal/slime/attacker,
	mob/living/simple_animal/slime/smacked,
	damage,
)
	if(smacked.buckled)
		smacked.Feedstop(silent = TRUE)
		smacked.visible_message(
			span_danger("[attacker] pulls [smacked] off!"),
			span_danger("You pull [smacked] off!"),
		)
		return

	if(smacked.nutrition >= 100) //steal some nutrition. negval handled in life()
		smacked.adjust_nutrition(-(50 + (40 * attacker.is_adult)))
		smacked.add_nutrition(50 + (40 * attacker.is_adult))
	if(smacked.health > 0)
		attacker.adjustBruteLoss(-10 + (-10 * attacker.is_adult))
