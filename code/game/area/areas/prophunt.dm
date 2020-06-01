/area/prophunt
	name = "PropHunt"
	icon_state = "Prophunt"
	dynamic_lighting = DYNAMIC_LIGHTING_DISABLED
	flags_1 = 0
	hidden = TRUE

	var/obj/machinery/computer/prophunt/linked
	var/restricted = 0 // if true, program goes on emag list

/*
	Power tracking: Use the prophunt computer's power grid
	Asserts are to avoid the inevitable infinite loops
*/

/area/prophunt/powered(var/chan)
	if(!requires_power)
		return 1
	if(always_unpowered)
		return 0
	if(!linked)
		return 0
	var/area/A = get_area(linked)
	ASSERT(!istype(A, /area/prophunt))
	return A.powered(chan)

/area/prophunt/addStaticPower(value, powerchannel)
	if(!linked)
		return
	var/area/A = get_area(linked)
	ASSERT(!istype(A, /area/prophunt))
	return ..()

/area/prophunt/use_power(amount, chan)
	if(!linked)
		return 0
	var/area/A = get_area(linked)
	ASSERT(!istype(A, /area/prophunt))
	return ..()


/*
	This is the standard prophunt.  It is intended to allow you to
	blow off steam by doing stupid things like laying down, throwing
	spheres at holes, or bludgeoning people.
*/
/area/prophunt/mg2
	name = "\improper Recreational prophunt"

/area/prophunt/mg2/offline
	name = "PropHunt - Offline"

/area/prophunt/mg2/00
	name = "PropHunt - Maintanence"

/area/prophunt/mg2/01
	name = "PropHunt - Crused Meta Showroom"

/area/prophunt/mg2/02
	name = "PropHunt - AI Sat I"

/area/prophunt/mg2/03
	name = "PropHunt - Bridge/Port Primary"

/area/prophunt/mg2/04
	name = "PropHunt - Engineering/Atmos Aux"

/area/prophunt/mg2/05
	name = "PropHunt - Delta Brig"

/area/prophunt/mg2/06
	name = "PropHunt - Pubby Brig"

/area/prophunt/mg2/07
	name = "PropHunt - Cursed Pubby Dorms"

/area/prophunt/mg2/08
	name = "PropHunt - Cargo Mashup"

/area/prophunt/mg2/09
	name = "PropHunt - Medbay Mishap"


// Bad programs

/area/prophunt/mg2/medical
	name = "PropHunt - Emergency Medical"
	restricted = 1