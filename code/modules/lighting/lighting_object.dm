/atom/movable/lighting_object
	name = ""
	anchored = TRUE
	icon = LIGHTING_ICON
	icon_state = null
	plane = LIGHTING_PLANE
	color = null //we manually set color in init instead
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	invisibility = INVISIBILITY_LIGHTING
	vis_flags = VIS_HIDE
	///whether we are already in the SSlighting.objects_queue list
	var/needs_update = FALSE

	///the turf that our light is applied to
	var/turf/affected_turf

/atom/movable/lighting_object/Initialize(mapload)
	if(!isturf(loc))
		qdel(src, force=TRUE)
		stack_trace("a lighting object was assigned to [loc], a non turf! ")
		return

	. = ..()

	verbs.Cut()

	affected_turf = loc
	if (affected_turf.lighting_object)
		qdel(affected_turf.lighting_object, force = TRUE)
		stack_trace("a lighting object was assigned to a turf that already had a lighting object!")

#warn need to pull off lumin tracking and starlight stuff

	affected_turf.lighting_object = src
	// Default to fullbright, so things can "see" if they use view() before we update
	affected_turf.luminosity = 0
	luminosity = 1


	// This path is really hot. this is faster
	// Really this should be a global var or something, but lets not think about that yes?
	for(var/turf/open/space/space_tile in RANGE_TURFS(1, affected_turf))
		space_tile.enable_starlight()

	needs_update = TRUE
	SSlighting.objects_queue += src

/atom/movable/lighting_object/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE
	SSlighting.objects_queue -= src
	if (loc != affected_turf)
		var/turf/oldturf = get_turf(affected_turf)
		var/turf/newturf = get_turf(loc)
		stack_trace("A lighting object was qdeleted with a different loc then it is suppose to have ([COORD(oldturf)] -> [COORD(newturf)])")
	if (isturf(affected_turf))
		affected_turf.lighting_object = null
		affected_turf.luminosity = 1
	affected_turf = null
	return ..()

