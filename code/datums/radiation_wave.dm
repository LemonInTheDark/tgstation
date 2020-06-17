/datum/radiation_wave
	/// The thing that spawned this radiation wave
	var/source
	/// The center of the wave
	var/turf/master_turf
	/// How far we've moved
	var/steps=0
	/// How strong it was originaly
	var/intensity
	/// Higher than 1 makes it drop off faster, 0.5 makes it drop off half etc
	var/range_modifier
	/// The direction of movement
	var/move_dir
	/// The directions to the side of the wave, stored for easy looping
	var/list/__dirs

/datum/radiation_wave/New(atom/_source, dir, _intensity=0, _range_modifier=RAD_DISTANCE_COEFFICIENT)

	source = "[_source] \[[REF(_source)]\]"

	master_turf = get_turf(_source)

	move_dir = dir
	__dirs = list()
	__dirs+=turn(dir, 90)
	__dirs+=turn(dir, -90)

	intensity = _intensity
	range_modifier = _range_modifier

	START_PROCESSING(SSradiation, src)

/datum/radiation_wave/Destroy()
	. = QDEL_HINT_IWILLGC
	STOP_PROCESSING(SSradiation, src)
	..()

/datum/radiation_wave/process()
	master_turf = get_step(master_turf, move_dir)
	if(!master_turf)
		qdel(src)
		return
	steps++
	var/list/atoms = get_rad_atoms()

	var/strength
	if(steps>1)
		strength = INVERSE_SQUARE(intensity, max(range_modifier*steps, 1), 1)
	else
		strength = intensity

	if(strength<RAD_BACKGROUND_RADIATION)
		qdel(src)
		return
	radiate(atoms, strength)
	check_obstructions(atoms) // reduce our overall strength if there are radiation insulators

/datum/radiation_wave/proc/get_rad_atoms()
	var/list/atoms = list()
	var/distance = steps
	var/cmove_dir = move_dir
	var/cmaster_turf = master_turf

	if(cmove_dir == NORTH || cmove_dir == SOUTH)
		distance-- //otherwise corners overlap

	atoms += get_rad_contents(cmaster_turf)

	var/turf/place
	for(var/dir in __dirs) //There should be just 2 dirs in here, left and right of the direction of movement
		place = cmaster_turf
		for(var/i in 1 to distance)
			place = get_step(place, dir)
			if(!place)
				break
			atoms += get_rad_contents(place)

	return atoms

/datum/radiation_wave/proc/check_obstructions(list/atoms)
	var/width = steps
	var/cmove_dir = move_dir
	if(cmove_dir == NORTH || cmove_dir == SOUTH)
		width--
	width = 1+(2*width)

	for(var/k in 1 to atoms.len)
		var/atom/thing = atoms[k]
		if(!thing)
			continue
		if (SEND_SIGNAL(thing, COMSIG_ATOM_RAD_WAVE_PASSING, src, width) & COMPONENT_RAD_WAVE_HANDLED)
			continue
		if (thing.rad_insulation != RAD_NO_INSULATION)
			intensity *= (1-((1-thing.rad_insulation)/width))

/datum/radiation_wave/proc/radiate(list/atoms, strength)
	for(var/k in atoms)
		var/atom/thing = k
		if(QDELETED(thing))
			continue
		thing.rad_act(strength)
