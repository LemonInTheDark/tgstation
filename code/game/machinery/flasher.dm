// It is a gizmo that flashes a small area

/obj/machinery/flasher
	name = "mounted flash"
	desc = "A wall-mounted flashbulb device."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "mflash1"
	base_icon_state = "mflash"
	max_integrity = 250
	integrity_failure = 0.4
	light_color = COLOR_WHITE
	light_power = FLASH_LIGHT_POWER
	damage_deflection = 10

	offset_north = DEFAULT_OFFSET_Y_NORTH
	offset_south = DEFAULT_OFFSET_Y_SOUTH
	offset_east = DEFAULT_OFFSET_X
	offset_west = DEFAULT_OFFSET_X

	var/obj/item/assembly/flash/handheld/bulb
	var/id = null
	var/on_wall = TRUE
	var/range = 2 //this is roughly the size of brig cell
	var/last_flash = 0 //Don't want it getting spammed like regular flashes
	var/strength = 100 //How knocked down targets are when flashed.

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/flasher, offset_north, offset_south, offset_east, offset_west)

/obj/machinery/flasher/portable //Portable version of the flasher. Only flashes when anchored
	name = "portable flasher"
	desc = "A portable flashing device. Wrench to activate and deactivate. Cannot detect slow movements."
	icon_state = "pflash1-p"
	base_icon_state = "pflash"
	strength = 80
	anchored = FALSE
	density = TRUE
	light_system = MOVABLE_LIGHT //Used as a flash here.
	light_range = FLASH_LIGHT_RANGE
	light_on = FALSE
	on_wall = FALSE
	///Proximity monitor associated with this atom, needed for proximity checks.
	var/datum/proximity_monitor/proximity_monitor

/obj/machinery/flasher/Initialize(mapload, ndir = 0, built = 0)
	. = ..() // ..() is EXTREMELY IMPORTANT, never forget to add it
	if(!built)
		bulb = new(src)

	if(on_wall)
		AddElement(/datum/element/wall_mount)


/obj/machinery/flasher/connect_to_shuttle(obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	id = "[port.id]_[id]"

/obj/machinery/flasher/Destroy()
	QDEL_NULL(bulb)
	return ..()

/obj/machinery/flasher/powered()
	if(!anchored || !bulb)
		return FALSE
	return ..()

/obj/machinery/flasher/update_icon_state()
	icon_state = "[base_icon_state]1[(bulb?.burnt_out || !powered()) ? "-p" : null]"
	return ..()

//Don't want to render prison breaks impossible
/obj/machinery/flasher/attackby(obj/item/W, mob/user, params)
	add_fingerprint(user)
	if (W.tool_behaviour == TOOL_WIRECUTTER)
		if (bulb)
			user.visible_message(span_notice("[user] begins to disconnect [src]'s flashbulb."), span_notice("You begin to disconnect [src]'s flashbulb..."))
			if(W.use_tool(src, user, 30, volume=50) && bulb)
				user.visible_message(span_notice("[user] disconnects [src]'s flashbulb!"), span_notice("You disconnect [src]'s flashbulb."))
				bulb.forceMove(loc)
				bulb = null
				power_change()

	else if (istype(W, /obj/item/assembly/flash/handheld))
		if (!bulb)
			if(!user.transferItemToLoc(W, src))
				return
			user.visible_message(span_notice("[user] installs [W] into [src]."), span_notice("You install [W] into [src]."))
			bulb = W
			power_change()
		else
			to_chat(user, span_warning("A flashbulb is already installed in [src]!"))

	else if (W.tool_behaviour == TOOL_WRENCH)
		if(!bulb)
			to_chat(user, span_notice("You start unsecuring the flasher frame..."))
			if(W.use_tool(src, user, 40, volume=50))
				to_chat(user, span_notice("You unsecure the flasher frame."))
				deconstruct(TRUE)
		else
			to_chat(user, span_warning("Remove a flashbulb from [src] first!"))
	else
		return ..()

//Let the AI trigger them directly.
/obj/machinery/flasher/attack_ai()
	if (anchored)
		return flash()

/obj/machinery/flasher/proc/flash()
	if (!powered() || !bulb)
		return

	if (bulb.burnt_out || (last_flash && world.time < src.last_flash + 150))
		return

	if(!bulb.flash_recharge(30)) //Bulb can burn out if it's used too often too fast
		power_change()
		return

	playsound(src.loc, 'sound/weapons/flash.ogg', 100, TRUE)
	flick("[base_icon_state]_flash", src)
	set_light_on(TRUE)
	addtimer(CALLBACK(src, .proc/flash_end), FLASH_LIGHT_DURATION, TIMER_OVERRIDE|TIMER_UNIQUE)

	last_flash = world.time
	use_power(1000)

	var/flashed = FALSE
	for (var/mob/living/L in viewers(src, null))
		if (get_dist(src, L) > range)
			continue

		if(L.flash_act(affect_silicon = 1))
			L.log_message("was AOE flashed by an automated portable flasher",LOG_ATTACK)
			L.Paralyze(strength)
			flashed = TRUE

	if(flashed)
		bulb.times_used++

	return 1


/obj/machinery/flasher/proc/flash_end()
	set_light_on(FALSE)


/obj/machinery/flasher/emp_act(severity)
	. = ..()
	if(!(machine_stat & (BROKEN|NOPOWER)) && !(. & EMP_PROTECT_SELF))
		if(bulb && prob(75/severity))
			flash()
			bulb.burn_out()
			power_change()

/obj/machinery/flasher/atom_break(damage_flag)
	. = ..()
	if(. && bulb)
		bulb.burn_out()
		power_change()

/obj/machinery/flasher/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		if(bulb)
			bulb.forceMove(loc)
			bulb = null
		if(disassembled)
			var/obj/item/wallframe/flasher/F = new(get_turf(src))
			transfer_fingerprints_to(F)
			F.id = id
			playsound(loc, 'sound/items/deconstruct.ogg', 50, TRUE)
		else
			new /obj/item/stack/sheet/iron (loc, 2)
	qdel(src)

/obj/machinery/flasher/portable/Initialize(mapload)
	. = ..()
	proximity_monitor = new(src, 0)

/obj/machinery/flasher/portable/HasProximity(atom/movable/AM)
	if (last_flash && world.time < last_flash + 150)
		return

	if(istype(AM, /mob/living/carbon))
		var/mob/living/carbon/M = AM
		if (M.m_intent != MOVE_INTENT_WALK && anchored)
			flash()

/obj/machinery/flasher/portable/attackby(obj/item/W, mob/user, params)
	if (W.tool_behaviour == TOOL_WRENCH)
		W.play_tool_sound(src, 100)

		if (!anchored && !isinspace())
			to_chat(user, span_notice("[src] is now secured."))
			add_overlay("[base_icon_state]-s")
			set_anchored(TRUE)
			power_change()
			proximity_monitor.set_range(range)
		else
			to_chat(user, span_notice("[src] can now be moved."))
			cut_overlays()
			set_anchored(FALSE)
			power_change()
			proximity_monitor.set_range(0)

	else
		return ..()

/obj/item/wallframe/flasher
	name = "mounted flash frame"
	desc = "Used for building wall-mounted flashers."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "mflash_frame"
	result_path = /obj/machinery/flasher
	var/id = null
	pixel_shift = 28

/obj/item/wallframe/flasher/examine(mob/user)
	. = ..()
	. += span_notice("Its channel ID is '[id]'.")

/obj/item/wallframe/flasher/after_attach(obj/O)
	..()
	var/obj/machinery/flasher/F = O
	F.id = id
