/obj/item/hypernoblium_crystal
	name = "Hypernoblium Crystal"
	desc = "Crystalized oxygen and hypernoblium stored in a bottle to pressureproof your clothes."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "potblue"
	var/uses = 2

/obj/item/hypernoblium_crystal/afterattack(atom/target, mob/user, proximity)
	. = ..()
	if(!proximity)
		return
	if(!istype(target, /obj/item/clothing))
		to_chat(user, span_warning("The crystal can only be used on clothing!"))
		return
	var/obj/item/clothing/hit_clothing = target
	if(istype(hit_clothing, /obj/item/clothing/suit/space))
		to_chat(user, span_warning("The [hit_clothing] is already pressure-resistant!"))
		return
	if(hit_clothing.min_cold_protection_temperature == SPACE_SUIT_MIN_TEMP_PROTECT && hit_clothing.clothing_flags & STOPSPRESSUREDAMAGE)
		to_chat(user, span_warning("[hit_clothing] is already pressure-resistant!"))
		return
	to_chat(user, span_notice("You see how the [hit_clothing] changes color, it's now pressure proof."))
	hit_clothing.name = "pressure-resistant [hit_clothing.name]"
	hit_clothing.remove_atom_colour(WASHABLE_COLOUR_PRIORITY)
	hit_clothing.add_atom_colour("#00fff7", FIXED_COLOUR_PRIORITY)
	hit_clothing.min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT
	hit_clothing.cold_protection = hit_clothing.body_parts_covered
	hit_clothing.clothing_flags |= STOPSPRESSUREDAMAGE
	uses--
	if(!uses)
		qdel(src)
