/datum/component/heat_sensitive
	var/datum/movement_detector/tracker

/datum/component/heat_sensitive/Initialize(max, min)
	if(!isatom(parent)) //How
		return COMPONENT_INCOMPATIBLE
	parent.typelist("heat-change", list("max" = max, "min" = min)) //Lets try and lower the memory impact of this yeah? Saves about 720 kb, might make things a bit slower, I think that's ok
	tracker = new /datum/movement_detector(parent, CALLBACK(src, .proc/reset_register))
	RegisterSignal(get_turf(parent), COMSIG_TURF_EXPOSE, .proc/check_requirements)

/datum/component/heat_sensitive/proc/reset_register(tracked, mover, oldloc)
	var/atom/old = oldloc
	UnregisterSignal(get_turf(old), COMSIG_TURF_EXPOSE)
	RegisterSignal(get_turf(tracked), COMSIG_TURF_EXPOSE, .proc/check_requirements)

/datum/component/heat_sensitive/proc/check_requirements(datum/source, datum/gas_mixture/mix, heat, volume)
	var/list/temp_recs = parent.typelist("heat-change")
	if(heat >= temp_recs["max"])
		SEND_SIGNAL(parent, COMSIG_HEAT_HOT, mix, heat, volume)
	if(heat <= temp_recs["min"])
		SEND_SIGNAL(parent, COMSIG_HEAT_COLD, mix, heat, volume)
