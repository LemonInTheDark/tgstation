/obj/machinery/door/poddoor/shutters
	gender = PLURAL
	name = "shutters"
	desc = "Heavy duty mechanical shutters with an atmospheric seal that keeps them airtight once closed."
	icon = 'icons/obj/doors/shutters.dmi'
	layer = SHUTTER_LAYER
	closingLayer = SHUTTER_LAYER
	damage_deflection = 20
	armor = list("melee" = 20, "bullet" = 20, "laser" = 20, "energy" = 75, "bomb" = 25, "bio" = 100, "rad" = 100, "fire" = 100, "acid" = 70)
	max_integrity = 100
	recipe_type = /datum/crafting_recipe/shutters
	can_crush = FALSE //They look more like upper and lower border objects
	var/mutable_appearance/our_overlay

GLOBAL_LIST_INIT(background_shutters_images, list(
	"closing" = mutable_appearance('icons/obj/doors/shutters.dmi', "closing_overlay", ABOVE_MOB_LAYER, GAME_PLANE),
	"closed" = mutable_appearance('icons/obj/doors/shutters.dmi', "closed_overlay", ABOVE_MOB_LAYER, GAME_PLANE),
	"opening" = mutable_appearance('icons/obj/doors/shutters.dmi', "opening_overlay", ABOVE_MOB_LAYER, GAME_PLANE),
	"open" = mutable_appearance('icons/obj/doors/shutters.dmi', "open_overlay", ABOVE_MOB_LAYER, GAME_PLANE),
))

/obj/machinery/door/poddoor/shutters/update_overlays()
	. = ..()
	our_overlay = mutable_appearance('icons/obj/doors/shutters.dmi', "[density ? "closed" : "open"]_overlay", ABOVE_MOB_LAYER, GAME_PLANE)

/obj/machinery/door/poddoor/shutters/do_animate(animation)
	. = ..()
	if(animation != "opening" && animation != "closing")
		return
	overlays -= our_overlay
	our_overlay = mutable_appearance('icons/obj/doors/shutters.dmi', "[animation]_overlay", ABOVE_MOB_LAYER, GAME_PLANE)
	overlays += our_overlay

/obj/machinery/door/poddoor/shutters/end_animate(animation)
	. = ..()
	if(animation != "opening" && animation != "closing")
		return
	overlays -= our_overlay

/obj/machinery/door/poddoor/shutters/preopen
	icon_state = "open"
	density = FALSE
	opacity = FALSE

/obj/machinery/door/poddoor/shutters/indestructible
	name = "hardened shutters"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/door/poddoor/shutters/radiation
	name = "radiation shutters"
	desc = "Lead-lined shutters with a radiation hazard symbol. Whilst this won't stop you getting irradiated, especially by a supermatter crystal, it will stop radiation travelling as far."
	icon = 'icons/obj/doors/shutters_radiation.dmi'
	icon_state = "closed"
	rad_insulation = RAD_EXTREME_INSULATION

/obj/machinery/door/poddoor/shutters/radiation/preopen
	icon_state = "open"
	density = FALSE
	opacity = FALSE
	rad_insulation = RAD_NO_INSULATION

/obj/machinery/door/poddoor/shutters/radiation/open()
	. = ..()
	rad_insulation = RAD_NO_INSULATION

/obj/machinery/door/poddoor/shutters/radiation/close()
	. = ..()
	rad_insulation = RAD_EXTREME_INSULATION

/obj/machinery/door/poddoor/shutters/window
	name = "windowed shutters"
	desc = "A shutter with a thick see-through polycarbonate window."
	icon = 'icons/obj/doors/shutters_window.dmi'
	icon_state = "closed"
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/poddoor/shutters/window/preopen
	icon_state = "open"
	density = FALSE

/obj/machinery/door/poddoor/shutters/bumpopen()
	return
