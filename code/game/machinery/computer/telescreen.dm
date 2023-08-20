/obj/machinery/computer/security/telescreen
	name = "\improper Telescreen"
	desc = "Used for watching an empty arena."
	icon = 'icons/obj/machines/telescreens.dmi'
	icon_state = "telescreen"
	base_icon_state = "telescreen"
	icon_keyboard = null
	layer = SIGN_LAYER
	network = list("thunder")
	density = FALSE
	circuit = null
	light_power = 0
	/// The kind of wallframe that this telescreen drops
	var/frame_type = /obj/item/wallframe/telescreen

/obj/item/wallframe/telescreen
	name = "telescreen frame"
	desc = "A wall-mountable telescreen frame. Apply to wall to use."
	icon = 'icons/obj/machines/telescreens.dmi'
	icon_state = "telescreen"
	result_path = /obj/machinery/computer/security/telescreen
	pixel_shift = 32

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen)

/obj/machinery/computer/security/telescreen/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/wall_mount)

/obj/machinery/computer/security/telescreen/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new frame_type(loc)
	qdel(src)

/obj/machinery/computer/security/telescreen/update_icon_state()
	icon_state = initial(icon_state)
	if(machine_stat & BROKEN)
		icon_state += "b"
	return ..()


/obj/machinery/computer/security/telescreen/entertainment
	name = "entertainment monitor"
	desc = "Damn, they better have the /tg/ channel on these things."
	icon = 'icons/obj/machines/status_display.dmi'
	icon_state = "entertainment_blank" // wallening todo - Should this be merged back into telescreens or keep using status display icons? Icon needs updating regardless.
	network = list()
	density = FALSE
	circuit = null
	interaction_flags_atom = INTERACT_ATOM_UI_INTERACT | INTERACT_ATOM_NO_FINGERPRINT_INTERACT | INTERACT_ATOM_NO_FINGERPRINT_ATTACK_HAND | INTERACT_MACHINE_REQUIRES_SIGHT
	frame_type = /obj/item/wallframe/telescreen/entertainment
	var/icon_state_off = "entertainment_blank"
	var/icon_state_on = "entertainment"

/obj/item/wallframe/telescreen/entertainment
	name = "entertainment telescreen frame"
	icon = 'icons/obj/machines/status_display.dmi'
	icon_state = "entertainment_blank"
	result_path = /obj/machinery/computer/security/telescreen/entertainment

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/entertainment) // Wallening todo: Depending on the comment on icon_state, adjust offset. Keep wall_mount element in mind.

/obj/machinery/computer/security/telescreen/entertainment/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_CLICK, PROC_REF(BigClick))
	update_appearance()

/obj/machinery/computer/security/telescreen/on_set_machine_stat(old_value)
	. = ..()
	update_appearance()

// Bypass clickchain to allow humans to use the telescreen from a distance
/obj/machinery/computer/security/telescreen/entertainment/proc/BigClick()
	SIGNAL_HANDLER

	if(!network.len)
		balloon_alert(usr, "nothing on TV!")
		return

	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom, interact), usr)

///Sets the monitor's icon to the selected state, and says an announcement
/obj/machinery/computer/security/telescreen/entertainment/proc/notify(on, announcement)
	if(on && icon_state == icon_state_off)
		icon_state = icon_state_on
	else
		icon_state = icon_state_off
	if(announcement)
		say(announcement)

// Wallening todo: does this show when it should, and hide when it shouldn't?
/obj/machinery/computer/security/telescreen/entertainment/update_overlays()
	. = ..()
	if(machine_stat & (NOPOWER|BROKEN))
		return
	. += "[base_icon_state]_program[rand(1,4)]"
	. += emissive_appearance(icon, "[base_icon_state]_emissive", src, alpha = src.alpha)

/// Adds a camera network ID to the entertainment monitor, and turns off the monitor if network list is empty
/obj/machinery/computer/security/telescreen/entertainment/proc/update_shows(is_show_active, tv_show_id, announcement)
	if(!network)
		return

	if(is_show_active)
		network |= tv_show_id
	else
		network -= tv_show_id

	notify(network.len, announcement)

/obj/machinery/computer/security/telescreen/rd
	name = "\improper Research Director's telescreen"
	desc = "Used for watching the AI and the RD's goons from the safety of his office."
	network = list("rd", "aicore", "aiupload", "minisat", "xeno", "test", "toxins")
	frame_type = /obj/item/wallframe/telescreen/rd

/obj/item/wallframe/telescreen/rd
	name = "\improper Research Director's telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/rd

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/rd)

/obj/machinery/computer/security/telescreen/research
	name = "research telescreen"
	desc = "A telescreen with access to the research division's camera network."
	network = list("rd")
	frame_type = /obj/item/wallframe/telescreen/research

/obj/item/wallframe/telescreen/research
	name = "research telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/research

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/research)

/obj/machinery/computer/security/telescreen/ce
	name = "\improper Chief Engineer's telescreen"
	desc = "Used for watching the engine, telecommunications and the minisat."
	network = list("engine", "singularity", "tcomms", "minisat")
	frame_type = /obj/item/wallframe/telescreen/ce

/obj/item/wallframe/telescreen/ce
	name = "\improper Chief Engineer's telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/ce

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/ce)

/obj/machinery/computer/security/telescreen/cmo
	name = "\improper Chief Medical Officer's telescreen"
	desc = "A telescreen with access to the medbay's camera network."
	network = list("medbay")
	frame_type = /obj/item/wallframe/telescreen/cmo

/obj/item/wallframe/telescreen/cmo
	name = "\improper Chief Engineer'stelescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/cmo

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/cmo)

/obj/machinery/computer/security/telescreen/vault
	name = "vault monitor"
	desc = "A telescreen that connects to the vault's camera network."
	network = list("vault")
	frame_type = /obj/item/wallframe/telescreen/vault

/obj/item/wallframe/telescreen/vault
	name = "vault telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/vault

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/vault)

/obj/machinery/computer/security/telescreen/ordnance
	name = "bomb test site monitor"
	desc = "A telescreen that connects to the bomb test site's camera."
	network = list("ordnance")
	frame_type = /obj/item/wallframe/telescreen/ordnance

/obj/item/wallframe/telescreen/ordnance
	name = "bomb test site telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/ordnance

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/ordnance)

/obj/machinery/computer/security/telescreen/engine
	name = "engine monitor"
	desc = "A telescreen that connects to the engine's camera network."
	network = list("engine")
	frame_type = /obj/item/wallframe/telescreen/engine

/obj/item/wallframe/telescreen/engine
	name = "engine telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/engine

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/engine)

/obj/machinery/computer/security/telescreen/turbine
	name = "turbine monitor"
	desc = "A telescreen that connects to the turbine's camera."
	network = list("turbine")
	frame_type = /obj/item/wallframe/telescreen/turbine

/obj/item/wallframe/telescreen/turbine
	name = "turbine telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/turbine

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/turbine)

/obj/machinery/computer/security/telescreen/interrogation
	name = "interrogation room monitor"
	desc = "A telescreen that connects to the interrogation room's camera."
	network = list("interrogation")
	frame_type = /obj/item/wallframe/telescreen/interrogation

/obj/item/wallframe/telescreen/interrogation
	name = "interrogation telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/interrogation

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/interrogation)

/obj/machinery/computer/security/telescreen/prison
	name = "prison monitor"
	desc = "A telescreen that connects to the permabrig's camera network."
	network = list("prison")
	frame_type = /obj/item/wallframe/telescreen/prison

/obj/item/wallframe/telescreen/prison
	name = "prison telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/prison

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/prison)

/obj/machinery/computer/security/telescreen/auxbase
	name = "auxiliary base monitor"
	desc = "A telescreen that connects to the auxiliary base's camera."
	network = list("auxbase")
	frame_type = /obj/item/wallframe/telescreen/auxbase

/obj/item/wallframe/telescreen/auxbase
	name = "auxiliary base telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/auxbase

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/auxbase)

/obj/machinery/computer/security/telescreen/minisat
	name = "minisat monitor"
	desc = "A telescreen that connects to the minisat's camera network."
	network = list("minisat")
	frame_type = /obj/item/wallframe/telescreen/minisat

/obj/item/wallframe/telescreen/minisat
	name = "minisat telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/minisat

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/minisat)

/obj/machinery/computer/security/telescreen/aiupload
	name = "\improper AI upload monitor"
	desc = "A telescreen that connects to the AI upload's camera network."
	network = list("aiupload")
	frame_type = /obj/item/wallframe/telescreen/aiupload

/obj/item/wallframe/telescreen/aiupload
	name = "\improper AI upload telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/aiupload

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/aiupload)

/obj/machinery/computer/security/telescreen/bar
	name = "bar monitor"
	desc = "A telescreen that connects to the bar's camera network. Perfect for checking on customers."
	network = list("bar")
	frame_type = /obj/item/wallframe/telescreen/bar

/obj/item/wallframe/telescreen/bar
	name = "bar telescreen frame"
	result_path = /obj/machinery/computer/security/telescreen/bar

WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/computer/security/telescreen/bar)

/// A button that adds a camera network to the entertainment monitors
/obj/machinery/button/showtime
	name = "thunderdome showtime button"
	desc = "Use this button to allow entertainment monitors to broadcast the big game."
	device_type = /obj/item/assembly/control/showtime
	req_access = list()
	id = "showtime_1"

/obj/machinery/button/showtime/Initialize(mapload)
	. = ..()
	if(device)
		var/obj/item/assembly/control/showtime/ours = device
		ours.id = id

/obj/item/assembly/control/showtime
	name = "showtime controller"
	desc = "A remote controller for entertainment monitors."
	/// Stores if the show associated with this controller is active or not
	var/is_show_active = FALSE
	/// The camera network id this controller toggles
	var/tv_network_id = "thunder"
	/// The display TV show name
	var/tv_show_name = "Thunderdome"
	/// List of phrases the entertainment console may say when the show begins
	var/list/tv_starters = list(
		"Feats of bravery live now at the thunderdome!",
		"Two enter, one leaves! Tune in now!",
		"Violence like you've never seen it before!",
		"Spears! Camera! Action! LIVE NOW!",
	)
	/// List of phrases the entertainment console may say when the show ends
	var/list/tv_enders = list(
		"Thank you for tuning in to the slaughter!",
		"What a show! And we guarantee next one will be bigger!",
		"Celebrate the results with Thundermerch!",
		"This show was brought to you by Nanotrasen.",
	)

/obj/item/assembly/control/showtime/activate()
	is_show_active = !is_show_active
	say("The [tv_show_name] show has [is_show_active ? "begun" : "ended"]")
	var/announcement = is_show_active ? pick(tv_starters) : pick(tv_enders)
	for(var/obj/machinery/computer/security/telescreen/entertainment/tv as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/security/telescreen/entertainment))
		tv.update_shows(is_show_active, tv_network_id, announcement)
