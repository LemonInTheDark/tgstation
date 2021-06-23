///Sets up an object to have fire_act called on it. Should this even be an element? I'm not sure
/datum/element/fire_sensitive
	var/list/signal_list = list(COMSIG_TURF_FIRE = /atom/proc/turf_fire_act)

/datum/element/fire_sensitive/Attach(datum/target)
	if(!isatom(target)) //How
		return ELEMENT_INCOMPATIBLE

	target.AddElement(/datum/element/connect_loc, signal_list)
	return ..()

/atom/proc/turf_fire_act(datum/source, exposed_temperature, volume)
	SIGNAL_HANDLER
	fire_act(exposed_temperature, volume)
