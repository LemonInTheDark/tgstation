// -- Bad modular quirks. --

// Rebalance of existing quirks
/datum/quirk/item_quirk/nearsighted
	value = -2

/datum/quirk/bad_touch
	value = -2

/datum/quirk/light_drinker
	desc = "You just can't handle your drinks and get drunk very quickly. (Disallowed: Skrell)"

// Modular quirks
// More vulnerabile to pain (increased pain modifier)
/datum/quirk/pain_vulnerability
	name = "Hyperalgesia"
	desc = "You're less resistant to pain - Your pain naturally decreases slower and you receive more overall."
	icon = FA_ICON_USER_INJURED
	value = -6
	gain_text = span_danger("You feel sharper.")
	lose_text = span_notice("You feel duller.")
	medical_record_text = "Patient has Hyperalgesia, and is more susceptible to pain stimuli than most."

/datum/quirk/pain_vulnerability/add()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.set_pain_mod(PAIN_MOD_QUIRK, 1.15)

/datum/quirk/pain_vulnerability/remove()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.unset_pain_mod(PAIN_MOD_QUIRK)

// More vulnerable to pain + get pain from more actions (Glass bones and paper skin)
/datum/quirk/allodynia
	name = "Allodynia"
	desc = "Your nerves are extremely sensitive - you may receive pain from things that wouldn't normally be painful, such as hugs."
	icon = FA_ICON_TIRED
	value = -10
	gain_text = span_danger("You feel fragile.")
	lose_text = span_notice("You feel less delicate.")
	medical_record_text = "Patient has Allodynia, and is extremely sensitive to touch, pain, and similar stimuli."
	COOLDOWN_DECLARE(time_since_last_touch)

/datum/quirk/allodynia/add()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.set_pain_mod(PAIN_MOD_QUIRK, 1.2)
	ADD_TRAIT(quirk_holder, TRAIT_EXTRA_PAIN, ROUNDSTART_TRAIT)
	RegisterSignal(quirk_holder, list(COMSIG_LIVING_GET_PULLED, COMSIG_CARBON_HELP_ACT), PROC_REF(cause_body_pain))
	RegisterSignal(quirk_holder, PROC_REF(cause_head_pain))

/datum/quirk/allodynia/remove()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.unset_pain_mod(PAIN_MOD_QUIRK)
	REMOVE_TRAIT(quirk_holder, TRAIT_EXTRA_PAIN, ROUNDSTART_TRAIT)
	UnregisterSignal(quirk_holder, list(COMSIG_LIVING_GET_PULLED, COMSIG_CARBON_HELP_ACT))

/*
 * Causes pain to arm zones if they're targeted, and the chest zone otherwise.
 *
 * source - quirk_holder / the mob being touched
 * toucher - the mob that's interacting with source (pulls, hugs, etc)
 */
/datum/quirk/allodynia/proc/cause_body_pain(datum/source, mob/living/toucher)
	SIGNAL_HANDLER

	if(!COOLDOWN_FINISHED(src, time_since_last_touch))
		return

	if(quirk_holder.stat != CONSCIOUS)
		return

	var/pain_zone = ( toucher.zone_selected == BODY_ZONE_L_ARM ? BODY_ZONE_L_ARM : ( toucher.zone_selected == BODY_ZONE_R_ARM ? BODY_ZONE_R_ARM : BODY_ZONE_CHEST ))

	to_chat(quirk_holder, span_danger("[toucher] touches you, causing a wave of sharp pain throughout your body!"))
	actually_hurt(pain_zone, 9)

/*
 * Causes pain to the head when they're headpatted.
 *
 * source - quirk_holder / the mob being touched
 * toucher - the mob that's headpatting
 */
/datum/quirk/allodynia/proc/cause_head_pain(datum/source, mob/living/patter)
	SIGNAL_HANDLER

	if(!COOLDOWN_FINISHED(src, time_since_last_touch))
		return

	if(quirk_holder.stat != CONSCIOUS)
		return

	to_chat(quirk_holder, span_danger("[patter] taps your head, causing a sensation of pain!"))
	actually_hurt(BODY_ZONE_HEAD, 7)

/*
 * Actually cause the pain to the target limb, causing a visual effect, emote, and a negative moodlet.
 *
 * zone - the body zone being affected
 * amount - the amount of pain being added
 */
/datum/quirk/allodynia/proc/actually_hurt(zone, amount)
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(!istype(carbon_holder))
		return

	new /obj/effect/temp_visual/annoyed(quirk_holder.loc)
	carbon_holder.cause_pain(zone, amount)
	INVOKE_ASYNC(quirk_holder, TYPE_PROC_REF(/mob, emote), pick(PAIN_EMOTES))
	quirk_holder.add_mood_event("bad_touch", /datum/mood_event/very_bad_touch)
	COOLDOWN_START(src, time_since_last_touch, 30 SECONDS)

// Prosthetic limb quirks (targeted limbs)
/datum/quirk/prosthetic_limb
	name = "Prosthetic Limb - Random"

/datum/quirk/prosthetic_limb/targeted
	value = -2
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_CHANGES_APPEARANCE //while parent doesn't change appearance because it's random, here we know for sure what limbs are prosthetic.
	abstract_parent_type = /datum/quirk/prosthetic_limb/targeted
	/// Typepath of what bodypart we're adding onto our person.
	var/obj/item/bodypart/replacement

/datum/quirk/prosthetic_limb/targeted/add_unique()
	if(!replacement)
		CRASH("Targeted prosthetic limb quirk tried to add a null replacement to [quirk_holder]!")
	var/mob/living/carbon/human/human_holder = quirk_holder
	if(!istype(human_holder))
		return
	var/obj/item/bodypart/prosthetic = new replacement
	slot_string = "[prosthetic.plaintext_zone]"

	human_holder.del_and_replace_bodypart(prosthetic, TRUE)

/datum/quirk/prosthetic_limb/targeted/left_arm
	name = "Prosthetic Limb - Left Arm"
	desc = "Your left arm is replaced with a prosthetic."
	replacement = /obj/item/bodypart/arm/left/robot/surplus

/datum/quirk/prosthetic_limb/targeted/right_arm
	name = "Prosthetic Limb - Right Arm"
	desc = "Your right arm is replaced with a prosthetic."
	replacement = /obj/item/bodypart/arm/right/robot/surplus

/datum/quirk/prosthetic_limb/targeted/left_leg
	name = "Prosthetic Limb - Left Leg"
	desc = "Your left leg is replaced with a prosthetic."
	replacement = /obj/item/bodypart/leg/left/robot/surplus

/datum/quirk/prosthetic_limb/targeted/right_leg
	name = "Prosthetic Limb - Right Leg"
	desc = "Your right leg is replaced with a prosthetic."
	replacement = /obj/item/bodypart/leg/right/robot/surplus

// Personally, the head being more prone to pain is a cool idea
/datum/quirk/glass_jaw
	desc = "Your jaw is weak and susceptible to knockouts if ample damage is applied. Its also much weaker to pain."

/datum/quirk/glass_jaw/add()
	. = ..()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.set_pain_mod(BODY_ZONE_HEAD, 1.50)

/datum/quirk/glass_jaw/add()
	var/mob/living/carbon/carbon_holder = quirk_holder
	if(istype(carbon_holder))
		carbon_holder.unset_pain_mod(PAIN_MOD_QUIRK)
	return ..()
