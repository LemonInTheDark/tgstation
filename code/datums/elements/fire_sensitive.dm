/datum/element/fire_sensitive
	//var/list/type_to_signal_path = list()
	var/list/signal_list = list(COMSIG_TURF_FIRE = /atom/proc/turf_fire_act)

/datum/element/fire_sensitive/Attach(datum/target)
	if(!isatom(target)) //How
		return ELEMENT_INCOMPATIBLE
	//var/signal_path = type_to_signal_path[target.type]
//	if(!signal_path)
	//	type_to_signal_path[target.type] = list(COMSIG_TURF_FIRE = "[target.type]/proc/turf_fire_act")
	//	signal_path = type_to_signal_path[target.type]

	target.AddElement(/datum/element/connect_loc, target, signal_list)
	return ..()

/atom/proc/turf_fire_act(datum/source, exposed_temperature, volume)
	SIGNAL_HANDLER
	fire_act(exposed_temperature, volume)
