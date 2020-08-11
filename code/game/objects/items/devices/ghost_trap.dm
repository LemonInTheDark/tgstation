/obj/item/ghost_trap
	name = "a spooky placeholder"
	desc = "some poem quote idk"
	icon = 'icons/obj/ghost_trap.dmi'
	icon_state = "waiting"
	var/deploying = FALSE

/obj/item/ghost_trap/attack_self(mob/user)
	toggle_anchor(user)
	//Text here
	return ..()

/obj/item/ghost_trap/crowbar_act(mob/living/user, obj/item/I)
	toggle_anchor(user)
	//Text here
	return ..()

/obj/item/ghost_trap/proc/toggle_anchor(mob/living/user)
	if(deploying)
		//Text here
		return
	deploying = TRUE
	if(!do_after(user, 1 SECONDS, target = src))
		deploying = FALSE
		return
	if(anchored)
		icon_state = "waiting"
	else
		icon_state = "set"
	anchored = !anchored
	deploying = FALSE
	if(isturf(loc))
		return
	user.dropItemToGround(src)
