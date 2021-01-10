/obj/item/ghost_trap
	name = "Spirit Catcher"
	desc = "A trap laid for the spirits of this world, 10 banshees in the first week or your money back!"
	icon = 'icons/obj/ghost_trap.dmi'
	icon_state = "waiting"
	var/deploying = FALSE

/obj/item/ghost_trap/Initialize()
	..()
	SSvis_overlays.add_vis_overlay(src, icon, "glow", layer, EMISSIVE_PLANE, dir, alpha)
	SSvis_overlays.add_vis_overlay(src, icon, "glow", layer, plane, dir, alpha)

/obj/item/ghost_trap/attack_self(mob/user)
	. = ..()
	toggle_anchor(user, "set up")

/obj/item/ghost_trap/crowbar_act(mob/living/user, obj/item/I)
	. = ..()
	if(!anchored)
		return
	toggle_anchor(user, "pry up")

/obj/item/ghost_trap/proc/toggle_anchor(mob/living/user, action)
	if(deploying)
		return
	deploying = TRUE
	to_chat(user, "<span class='notice'>You start to [action] [src].</span>")
	if(!do_after(user, 1 SECONDS, target = src))
		deploying = FALSE
		return
	to_chat(user, "<span class='notice'>You [action] [src].</span>")
	anchored = !anchored
	if(anchored)
		icon_state = "set"
	else
		icon_state = "waiting"
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
	desc = "Contains a trapped spirit, works as an inteligence core"
	icon = 'icons/obj/ghost_trap.dmi'
	icon_state = "filled"
	w_class = WEIGHT_CLASS_NORMAL
	brain_name = "spirit"
	radio_check = FALSE

/obj/item/mmi/ghost_core/add_mmi_overlay()
	return

/obj/item/mmi/ghost_core/attackby()
	return

/obj/item/mmi/ghost_core/attack_self(mob/user)
	radio.on = !radio.on
	to_chat(user, "<span class='notice'>You toggle [src]'s radio system [radio.on==1 ? "on" : "off"].</span>")

/obj/item/mmi/ghost_core/proc/transfer_personality(mob/spook)
	if(brainmob || !spook.mind)
		return
	set_brainmob(new /mob/living/brain(src))
	spook.mind.transfer_to(brainmob)
	brainmob.container = src
	name = "[initial(name)] ([spook.name])"
	brainmob.name = name
	var/policy = get_policy(ROLE_POSIBRAIN)
	if(policy)
		to_chat(brainmob, policy)
	brainmob.set_stat(CONSCIOUS)
	brainmob.remove_from_dead_mob_list()
	brainmob.add_to_alive_mob_list()
	to_chat(brainmob, "<span class='warning'>You've been captured!</span>")
	return TRUE
