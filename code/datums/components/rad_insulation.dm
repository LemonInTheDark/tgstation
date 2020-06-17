/datum/component/rad_insulation
	var/amount					// Multiplier for radiation strength passing through

/datum/component/rad_insulation/Initialize(_amount=RAD_MEDIUM_INSULATION, protects=TRUE, contamination_proof=TRUE)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

	if(protects) // Does this protect things in its contents from being affected?
		RegisterSignal(parent, COMSIG_ATOM_RAD_PROBE, .proc/rad_probe_react)
	if(_amount != 1) // If it's 1 it won't have any impact on radiation passing through anyway
		RegisterSignal(parent, COMSIG_ATOM_RAD_WAVE_PASSING, .proc/rad_pass)

	amount = _amount

/datum/component/rad_insulation/proc/rad_probe_react(datum/source)
	return COMPONENT_BLOCK_RADIATION

/datum/component/rad_insulation/proc/rad_pass(datum/source, datum/radiation_wave/wave, width)
	wave.intensity = wave.intensity*(1-((1-amount)/width)) // The further out the rad wave goes the less it's affected by insulation (larger width)
	return COMPONENT_RAD_WAVE_HANDLED
