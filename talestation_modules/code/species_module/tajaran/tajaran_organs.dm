// Tajaran ears
/obj/item/organ/internal/ears/tajaran_ears
	name = "tajaran ears"
	visual = TRUE
	damage_multiplier = 2

// Tajaran tail
/obj/item/organ/external/tail/tajaran_tail
	slot = ORGAN_SLOT_EXTERNAL_TAIL
	dna_block = DNA_TAJARAN_TAIL_BLOCK
	name = "tajaran tail"
	desc = "A severed tajaran tail. What poor bastard would do such a thing?"
	preference = "feature_tajaran_tail"
	icon = 'talestation_modules/icons/species/organs.dmi'
	icon_state = "severedtailtaj"
	wag_flags = WAG_ABLE

	bodypart_overlay = /datum/bodypart_overlay/mutant/tail/tajaran_tail

/datum/bodypart_overlay/mutant/tail/tajaran_tail
	feature_key = "tajaran_tail"

/datum/bodypart_overlay/mutant/tail/tajaran_tail/can_draw_on_bodypart(mob/living/carbon/human/human)
	if(human.wear_suit && (human.wear_suit.flags_inv & HIDEJUMPSUIT))
		return FALSE
	return TRUE

/datum/bodypart_overlay/mutant/tail/tajaran_tail/get_global_feature_list()
	return GLOB.tajaran_tail_list

// Tajaran snouts
/obj/item/organ/external/snout/tajaran_snout
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_EXTERNAL_TAJARAN_SNOUT
	dna_block = DNA_TAJARAN_SNOUT_BLOCK
	preference = "feature_tajaran_snout"
	external_bodytypes = BODYTYPE_SNOUTED

	bodypart_overlay = /datum/bodypart_overlay/mutant/snout/tajaran_snout

/datum/bodypart_overlay/mutant/snout/tajaran_snout
	layers = EXTERNAL_ADJACENT
	feature_key = "tajaran_snout"

/datum/bodypart_overlay/mutant/snout/tajaran_snout/can_draw_on_bodypart(mob/living/carbon/human/human)
	if(!(human.wear_mask?.flags_inv & HIDESNOUT) && !(human.head?.flags_inv & HIDESNOUT))
		return TRUE
	return FALSE

/datum/bodypart_overlay/mutant/snout/tajaran_snout/get_global_feature_list()
	return GLOB.tajaran_snout_list

/obj/item/organ/internal/tongue/tajaran
	name = "tajaran tongue"
	desc = "Tajaran tongues are known for their rough patch of connective tissue.\
				They don't make great kissers."
	say_mod = "meows"
	languages_native = /datum/language/tajaran
	var/static/list/languages_possible_tajaran

/obj/item/organ/internal/tongue/tajaran/get_possible_languages()
	return ..() + /datum/language/tajaran
