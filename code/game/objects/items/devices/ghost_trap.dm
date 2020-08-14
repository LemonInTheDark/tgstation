/obj/item/ghost_trap
	name = "Spirit Catcher"
	desc = "The label says \"Purpose built to catch meddling spirits and trap them in a core for our customers to use as an inteligence drive. (WF INC)\""
	icon = 'icons/obj/ghost_trap.dmi'
	icon_state = "waiting"
	var/deploying = FALSE

/obj/item/ghost_trap/Initialize()
	..()
	SSvis_overlays.add_vis_overlay(src, icon, "glow", layer, EMISSIVE_PLANE, dir, alpha)
	SSvis_overlays.add_vis_overlay(src, icon, "glow", layer, plane, dir, alpha)

/obj/item/ghost_trap/attack_self(mob/user)
	to_chat(user, "<span class='notice'>You start to set up [src]</span>")
	toggle_anchor(user)
	return ..()

/obj/item/ghost_trap/crowbar_act(mob/living/user, obj/item/I)
	..()
	if(!anchored)
		return
	to_chat(user, "<span class='notice'>You start to pry up [src].</span>")
	toggle_anchor(user)

/obj/item/ghost_trap/proc/toggle_anchor(mob/living/user)
	if(deploying)
		return
	deploying = TRUE
	if(!do_after(user, 1 SECONDS, target = src))
		deploying = FALSE
		return
	if(anchored)
		icon_state = "waiting"
		to_chat(user, "<span class='notice'>You pry up [src].</span>")
	else
		icon_state = "set"
		to_chat(user, "<span class='notice'>You set up [src]</span>")
	anchored = !anchored
	deploying = FALSE
	if(isturf(loc))
		return
	user.dropItemToGround(src)

/obj/item/ghost_trap/Crossed(atom/movable/AM, oldloc)
	if(anchored && istype(AM, /mob/living/simple_animal/spirit))
		var/obj/item/mmi/ghost_core/spook = new(loc)
		spook.transfer_personality(AM)
		qdel(AM)
		qdel(src)
	return ..()

/obj/item/mmi/ghost_core
	name = "Ghost Core"
	desc = "Contains a trapped spirit, wonder what this could go into. You're not sure how they made this thing, but it's really convoluted."
	icon = 'icons/obj/ghost_trap.dmi'
	icon_state = "filled"
	w_class = WEIGHT_CLASS_NORMAL
	brain_name = "spirit"
	radio_check = FALSE

/obj/item/mmi/ghost_core/Initialize()
	. = ..()
	brainmob = new(src)

/obj/item/mmi/ghost_core/update_icon_state()
	return ..()

/obj/item/mmi/ghost_core/add_mmi_overlay()
	return

/obj/item/mmi/ghost_core/attackby()
	return

/obj/item/mmi/ghost_core/attack_self(mob/user)
	radio.on = !radio.on
	to_chat(user, "<span class='notice'>You toggle [src]'s radio system [radio.on==1 ? "on" : "off"].</span>")

/obj/item/mmi/ghost_core/proc/transfer_personality(mob/spook)
	if(QDELETED(brainmob))
		return
	if(spook.mind)
		spook.mind.transfer_to(brainmob)
	else
		brainmob.ckey = spook.ckey
	name = "[initial(name)] ([spook.name])"
	var/policy = get_policy(ROLE_POSIBRAIN)
	if(policy)
		to_chat(brainmob, policy)
	brainmob.set_stat(CONSCIOUS)
	brainmob.remove_from_dead_mob_list()
	brainmob.add_to_alive_mob_list()
	to_chat(brainmob, "<span class='warning'>You've been captured! </span>")
	return TRUE
