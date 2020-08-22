/obj/item/ectoattractor
	name = "Ectoattractor"
	dest = "A strange little gun, it's got a label on it"
	icon = 'icons/obj/guns/energy.dmi'
	icon_state = "ectoattacter"
	reach = 7

/obj/item/ectoattractor/examine_more(mob/user)
	return "The label reads \"The Ectoattractor MK2, built to extract the souls of your foes. Do not ask what the first one did, we targeted it poorly. WIZCORP TM \""

/obj/item/ectoattractor/melee_attack_chain(mob/user, atom/target, params)
	//this will wrap at 127, if it's important write a helper function
	if(get_dist(user, target) > 1 && !istype(target, /mob/living/simple_animal/spirit)) //Gonna do a type check here, any more and you should make it a flag
		return FALSE
	return ..()
