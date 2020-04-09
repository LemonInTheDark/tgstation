/*
CONTAINS:
RSF

*/
/obj/item/rsf
	name = "\improper Rapid-Service-Fabricator"
	desc = "A device used to rapidly deploy service items."
	icon = 'icons/obj/tools.dmi'
	icon_state = "rsf"
	///The icon state to revert to when the tool is empty
	var/spent_icon_state = "rsf_empty"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	opacity = 0
	density = FALSE
	anchored = FALSE
	item_flags = NOBLUDGEON
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 0, "acid" = 0)
	///The current matter count
	var/matter = 0
	///The max amount of matter in the device
	var/max_matter = 30
	///The type of the object we are going to dispense
	var/to_dispense
	///The cost of the object we are going to dispense
	var/dispense_cost = 0
	w_class = WEIGHT_CLASS_NORMAL
	///An associated list of atoms and charge costs. This can contain a seperate list, as long as it's associated item is an object
	var/list/cost_by_item = list(/obj/item/reagent_containers/food/drinks/drinkingglass = 20,
								/obj/item/paper = 10,
								/obj/item/storage/pill_bottle/dice = 200,
								/obj/item/pen = 50,
								/obj/item/clothing/mask/cigarette = 10,
								)
	///An associated list of fuel and it's value
	var/list/matter_by_item = list(/obj/item/rcd_ammo = 10,)
	///A list of surfaces that we are allowed to place things on.
	var/list/allowed_surfaces = list(/turf/open/floor, /obj/structure/table)
	///The unit of mesure of the matter, for use in text
	var/discriptor = "fabrication-units"
	///The verb that describes what we're doing, for use in text
	var/action_type = "Dispensing"

/obj/item/rsf/Initialize()
	. = ..()
	to_dispense = cost_by_item[1]

/obj/item/rsf/examine(mob/user)
	. = ..()
	. += "<span class='notice'>It currently holds [matter]/[max_matter] [discriptor].</span>"

/obj/item/rsf/cyborg
	matter = 30

/obj/item/rsf/attackby(obj/item/W, mob/user, params)
	if(is_type_in_list(W,matter_by_item))//If the thing we got hit by is in our matter list
		var/tempMatter = matter_by_item[W.type] + matter
		if(tempMatter > max_matter)
			to_chat(user, "<span class='warning'>\The [src] can't hold any more [discriptor]!</span>")
			return
		qdel(W)
		matter = tempMatter //We add its value
		playsound(src.loc, 'sound/machines/click.ogg', 10, TRUE)
		to_chat(user, "<span class='notice'>\The [src] now holds [matter]/[max_matter] [discriptor].</span>")
		icon_state = initial(icon_state)//and set the icon state to the initial value it had
	else
		return ..()

/obj/item/rsf/attack_self(mob/user)
	if(!user)
		return
	playsound(src.loc, 'sound/effects/pop.ogg', 50, FALSE)
	var/list/item_list
	var/atom/target = cost_by_item
	var/cost = 0
	//Warning, prepare for bodgecode
	while(istype(target, /list/))//While target is a list we continue the loop
		var/picked = show_radial_menu(user, src, formRadial(target), custom_check = CALLBACK(src, .proc/check_menu, user), require_near = TRUE)
		if(!check_menu(user) || picked == null)
			return
		for(var/emem in target)//Back through target agian
			var/atom/test = extractObject(target, emem)
			if(picked == test.name)//We try and find the entry that matches the radial selection
				cost = target[emem]//We cash the cost
				target = emem
				break
			qdel(test)
		//If we found a list we start it all again, this time looking through its contents.
	to_dispense = target
	dispense_cost = cost
	// Change mode

/obj/item/rsf/proc/extractObject(from, input)
	var/atom/test
	if(istype(input, /list/))
		var/temp = target[input]//If it's a list we should use its associated object
		test = new temp()
	else
		test = new input()
	return test

/obj/item/rsf/proc/formRadial(from)
	radial_list = list()
	for(var/meme in from)//We iterate through all of targets entrys
		var/atom/test = extractObject(from, meme)
		//We then add their data into the radial menu
		radial_list[test.name] = image(icon = test.icon, icon_state = test.icon_state)
		qdel(test)
	return radial_list

/obj/item/rsf/proc/check_menu(mob/user)
	if(!istype(user))
		return FALSE
	if(user.incapacitated() || !user.Adjacent(src))
		return FALSE
	return TRUE

/obj/item/rsf/afterattack(atom/A, mob/user, proximity)
	. = ..()
	if(!proximity)
		return
	if(!is_allowed(A))
		return
	if(use_matter(dispense_cost, user))//If we can charge that amount of charge, we do so and return true
		playsound(src.loc, 'sound/machines/click.ogg', 10, TRUE)
		var/atom/meme = new to_dispense(get_turf(A))
		to_chat(user, "<span class='notice'>[action_type] [meme.name]...</span>")

///A helper proc. checks to see if we can afford the amount of charge that is passed, and if we can docs the charge from our base, and returns TRUE. If we can't we return FALSE
/obj/item/rsf/proc/use_matter(charge, mob/user)
	if(iscyborg(user))
		var/mob/living/silicon/robot/R = user
		var/end_charge = R.cell.charge - charge
		if(end_charge >= 0)
			R.cell.charge = end_charge
			return TRUE
		to_chat(user, "<span class='warning'>You do not have enough power to use [src].</span>")
	else
		if(matter - 1 >= 0)
			matter--
			to_chat(user, "<span class='notice'>\The [src] now holds [matter]/[max_matter] [discriptor].</span>")
			return TRUE
		to_chat(user, "<span class='warning'>\The [src] doesn't have enough [discriptor] left.</span>")
	icon_state = spent_icon_state
	return FALSE

///Helper proc that iterates through all the things we are allowed to spawn on, and sees if the passed atom is one of them
/obj/item/rsf/proc/is_allowed(atom/to_check)
	for(var/sort in allowed_surfaces)
		if(istype(to_check, sort))
			return TRUE
	return FALSE

/obj/item/rsf/cookiesynth
	name = "Cookie Synthesizer"
	desc = "A self-recharging device used to rapidly deploy cookies."
	icon_state = "rcd"
	spent_icon_state = "rcd"
	var/toxin = FALSE
	var/cooldown = 0
	var/cooldowndelay = 10
	max_matter = 10
	cost_by_item = list()
	dispense_cost = 100
	discriptor = "cookie-units"
	action_type = "Fabricates"

/obj/item/rsf/cookiesynth/Initialize()
	. = ..()
	START_PROCESSING(SSprocessing, src)

/obj/item/rsf/cookiesynth/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/obj/item/rsf/cookiesynth/attackby()
	return

/obj/item/rsf/cookiesynth/emag_act(mob/user)
	obj_flags ^= EMAGGED
	if(obj_flags & EMAGGED)
		to_chat(user, "<span class='warning'>You short out [src]'s reagent safety checker!</span>")
	else
		to_chat(user, "<span class='warning'>You reset [src]'s reagent safety checker!</span>")

/obj/item/rsf/cookiesynth/attack_self(mob/user)
	var/mob/living/silicon/robot/P = null
	if(iscyborg(user))
		P = user
	if(((obj_flags & EMAGGED) || (P && P.emagged)) && !toxin)
		toxin = TRUE
		to_dispense = /obj/item/reagent_containers/food/snacks/cookie/sleepy
		to_chat(user, "<span class='alert'>Cookie Synthesizer hacked.</span>")
	else
		toxin = FALSE
		to_dispense = /obj/item/reagent_containers/food/snacks/cookie
		to_chat(user, "<span class='notice'>Cookie Synthesizer reset.</span>")

/obj/item/rsf/cookiesynth/process()
	matter = min(matter + 1, max_matter) //We add 1 up to a point

/obj/item/rsf/cookiesynth/afterattack(atom/A, mob/user, proximity)
	if(cooldown > world.time)
		return
	. = ..()
	cooldown = world.time + cooldowndelay
