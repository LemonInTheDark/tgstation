// Because we can control each corner of every lighting object.
// And corners get shared between multiple turfs (unless you're on the corners of the map, then 1 corner doesn't).
// For the record: these should never ever ever be deleted, even if the turf doesn't have dynamic lighting.

/datum/lighting_corner
	var/list/datum/light_source/affecting // Light sources affecting us.
	var/list/datum/light_source/potentially_affecting // Light sources POTENTIALLY affecting us. Waiting to be updated if something happens to us

	var/x = 0
	var/y = 0
	var/z = 0

	var/turf/master_NE
	var/turf/master_SE
	var/turf/master_SW
	var/turf/master_NW

	//"raw" color values, changed by update_lumcount()
	var/lum_r = 0
	var/lum_g = 0
	var/lum_b = 0

	//true color values, guaranteed to be between 0 and 1
	var/cache_r = LIGHTING_SOFT_THRESHOLD
	var/cache_g = LIGHTING_SOFT_THRESHOLD
	var/cache_b = LIGHTING_SOFT_THRESHOLD

	///the maximum of lum_r, lum_g, and lum_b. if this is > 1 then the three cached color values are divided by this
	var/largest_color_luminosity = 0

	///whether we are to be added to SSlighting's corners_queue list for an update
	var/needs_update = FALSE

	///lazy list of base lighting keys -> list of all rgb values, sorted by intensity and paired with the amount of each
	var/list/base_light_keys

// Takes as an argument the coords to use as the bottom left (south west) of our corner
/datum/lighting_corner/New(x, y, z)
	. = ..()

	src.x = x + 0.5
	src.y = y + 0.5
	src.z = z

	// Alright. We're gonna take a set of coords, and from them do a loop clockwise
	// To build out the turfs adjacent to us. This is pretty fast
	var/turf/process_next = locate(x, y, z)
	if(process_next)
		master_SW = process_next
		process_next.lighting_corner_NE = src
		// Now, we go north!
		process_next = get_step(process_next, NORTH)
	else
		// Yes this is slightly slower then having a guarenteeed turf, but there aren't many null turfs
		// So this is pretty damn fast
		process_next = locate(x, y + 1, z)

	// Ok, if we have a north turf, go there. otherwise, onto the next
	if(process_next)
		master_NW = process_next
		process_next.lighting_corner_SE = src
		// Now, TO THE EAST
		process_next = get_step(process_next, EAST)
	else
		process_next = locate(x + 1, y + 1, z)

	// Etc etc
	if(process_next)
		master_NE = process_next
		process_next.lighting_corner_SW = src
		// Now, TO THE SOUTH AGAIN (SE)
		process_next = get_step(process_next, SOUTH)
	else
		process_next = locate(x + 1, y, z)

	// anddd the last tile
	if(process_next)
		master_SE = process_next
		process_next.lighting_corner_NW = src

/datum/lighting_corner/proc/self_destruct_if_idle()
	if (!LAZYLEN(affecting) && !LAZYLEN(potentially_affecting))
		qdel(src, force = TRUE)

/datum/lighting_corner/proc/vis_update()
	for (var/datum/light_source/light_source as anything in affecting)
		light_source.vis_update()

/datum/lighting_corner/proc/queued_update()
	for (var/datum/light_source/light_source as anything in potentially_affecting)
		light_source.recalc_corner(src)

/datum/lighting_corner/proc/full_update()
	for (var/datum/light_source/light_source as anything in affecting + potentially_affecting)
		light_source.recalc_corner(src)

// God that was a mess, now to do the rest of the corner code! Hooray!
/datum/lighting_corner/proc/update_lumcount(delta_r, delta_g, delta_b)

#ifdef VISUALIZE_LIGHT_UPDATES
	if (!SSlighting.allow_duped_values && !(delta_r || delta_g || delta_b)) // 0 is falsey ok
		return
#else
	if (!(delta_r || delta_g || delta_b)) // 0 is falsey ok
		return
#endif

	lum_r += delta_r
	lum_g += delta_g
	lum_b += delta_b

	if (!needs_update)
		needs_update = TRUE
		SSlighting.corners_queue += src

#define SORT_COMPARE_BASELIGHT(a) (a[1] + a[2] + a[3])
GLOBAL_LIST_EMPTY(base_light_strings)
/proc/get_base_light_list(r, g, b)
	var/list/hand_back = GLOB.base_light_strings["[r]-[g]-[b]"]
	if(hand_back)
		return hand_back
	hand_back = new /list(3)
	hand_back[1] = r
	hand_back[2] = g
	hand_back[3] = b
	GLOB.base_light_strings["[r]-[g]-[b]"] = hand_back
	return hand_back

/// Update a corner based off old and new BASE rgb values
/// The idea here is we only ever use one value per key per corner
/// So we sort our input lights based off brightness, and pull the strongest one
/// And just store the others
/datum/lighting_corner/proc/update_base_lumcount(key, r, g, b, old_r, old_g, old_b)
// I want a way to instead of passing in a set of red/green/blue, pass in an index to an array (this will be cheap because we assume base lights are low range)
// 1. If a light source has a base, generate a unique key that matches all its visual properties. This combined with the base will be the passed in key here
// 2. Use this key to generate a sorted list of all the light lists we can generate
// 3. Replace all light lists in the map with their index in the sorted list
// 4. Store both the map and the sorted list, pass the old and new index into these procs, alongside the cached sorted list
// This would give me sorting for free, and all I'd need to do to is this
// 0. Store the length of the index list
// 1. Decrement the old index, if its entry is 0 remove the index
// 2. Increment the new index. If its entry is NEW expand the list to fit it
// 3. Go to the end of the list. Check to see if it has a value. If not, step back one
// 4. Go until you find a value, then collapse the list to fit. that index is your new color
// 5. If the old and new indexes are the same, discard
// 6. Index the global color list with the new and old index, removing one and adding the other
	if(!(r || g || b))
		remove_base_lumcount(key, old_r, old_g, old_b)
		return
	LAZYINITLIST(base_light_keys)
	// first, we find the old entries
	var/list/counted_entry
	var/list/our_entries = base_light_keys[key]
	var/list_modified = FALSE
	if(our_entries)
		counted_entry = our_entries[length(our_entries)]
		var/list/old_entry = get_base_light_list(old_r, old_g, old_b)
		var/reduced_count = our_entries[old_entry] - 1
		if(reduced_count > 0)
			our_entries[old_entry] = reduced_count
		else
			our_entries -= list(old_entry)
			list_modified = TRUE
			if(!length(our_entries))
				base_light_keys -= key
				UNSETEMPTY(base_light_keys)
	else
		base_light_keys[key] = our_entries = list()

	// Alright, now we're gonna do a binary insert
	var/list/new_entry = get_base_light_list(r, g, b)
	var/increased_count = our_entries[new_entry] + 1
	if(increased_count == 1)
		BINARY_INSERT_DEFINE(list(new_entry), our_entries, SORT_VAR_NO_TYPE, new_entry, SORT_COMPARE_BASELIGHT, COMPARE_KEY)
		list_modified = TRUE
	our_entries[new_entry] = increased_count

	if(list_modified && new_entry == our_entries[length(our_entries)])
		lum_r += new_entry[1]
		lum_g += new_entry[2]
		lum_b += new_entry[3]
		if(counted_entry)
			lum_r -= counted_entry[1]
			lum_g -= counted_entry[2]
			lum_b -= counted_entry[3]
		if (!needs_update)
			needs_update = TRUE
			SSlighting.corners_queue += src

/datum/lighting_corner/proc/remove_base_lumcount(key, r, g, b)
	if(!(r || g || b))
		return
	LAZYINITLIST(base_light_keys)
	// first, we find the old entries
	var/list/our_entries = base_light_keys[key]
	if(!our_entries)
		return
	var/list/counted_entry = our_entries[length(our_entries)]

	var/list/old_entry = get_base_light_list(r, g, b)
	var/reduced_count = our_entries[old_entry] - 1
	if(reduced_count > 0)
		our_entries[old_entry] = reduced_count
		return
	our_entries -= list(old_entry)

	var/list/new_entry
	if(length(our_entries))
		new_entry = our_entries[length(our_entries)]
	else
		base_light_keys -= key
		UNSETEMPTY(base_light_keys)

	if(counted_entry != new_entry)
		lum_r -= counted_entry[1]
		lum_g -= counted_entry[2]
		lum_b -= counted_entry[3]
		if(new_entry)
			lum_r += new_entry[1]
			lum_g += new_entry[2]
			lum_b += new_entry[3]

		if (!needs_update)
			needs_update = TRUE
			SSlighting.corners_queue += src

/datum/lighting_corner/proc/update_objects()
	// Cache these values ahead of time so 4 individual lighting objects don't all calculate them individually.
	var/lum_r = src.lum_r
	var/lum_g = src.lum_g
	var/lum_b = src.lum_b
	var/largest_color_luminosity = max(lum_r, lum_g, lum_b) // Scale it so one of them is the strongest lum, if it is above 1.
	. = 1 // factor
	if (largest_color_luminosity > 1)
		. = 1 / largest_color_luminosity

	var/old_r = cache_r
	var/old_g = cache_g
	var/old_b = cache_b

	#if LIGHTING_SOFT_THRESHOLD != 0
	else if (largest_color_luminosity < LIGHTING_SOFT_THRESHOLD)
		. = 0 // 0 means soft lighting.

	cache_r = round(lum_r * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	cache_g = round(lum_g * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	cache_b = round(lum_b * ., LIGHTING_ROUND_VALUE) || LIGHTING_SOFT_THRESHOLD
	#else
	cache_r = round(lum_r * ., LIGHTING_ROUND_VALUE)
	cache_g = round(lum_g * ., LIGHTING_ROUND_VALUE)
	cache_b = round(lum_b * ., LIGHTING_ROUND_VALUE)
	#endif

	src.largest_color_luminosity = round(largest_color_luminosity, LIGHTING_ROUND_VALUE)
#ifdef VISUALIZE_LIGHT_UPDATES
	if(!SSlighting.allow_duped_corners && old_r == cache_r && old_g == cache_g && old_b == cache_b)
		return
#else
	if(old_r == cache_r && old_g == cache_g && old_b == cache_b)
		return
#endif

	var/datum/lighting_object/lighting_object = master_NE?.lighting_object
	if (lighting_object && !lighting_object.needs_update)
		lighting_object.needs_update = TRUE
		SSlighting.objects_queue += lighting_object

	lighting_object = master_SE?.lighting_object
	if (lighting_object && !lighting_object.needs_update)
		lighting_object.needs_update = TRUE
		SSlighting.objects_queue += lighting_object

	lighting_object = master_SW?.lighting_object
	if (lighting_object && !lighting_object.needs_update)
		lighting_object.needs_update = TRUE
		SSlighting.objects_queue += lighting_object

	lighting_object = master_NW?.lighting_object
	if (lighting_object && !lighting_object.needs_update)
		lighting_object.needs_update = TRUE
		SSlighting.objects_queue += lighting_object

	self_destruct_if_idle()


/datum/lighting_corner/dummy/New()
	return

/datum/lighting_corner/Destroy(force)
	if (!force)
		return QDEL_HINT_LETMELIVE


	for (var/datum/light_source/light_source as anything in affecting)
		LAZYREMOVE(light_source.effect_str, src)
	affecting = null
	for (var/datum/light_source/light_source as anything in potentially_affecting)
		LAZYREMOVE(light_source.potential_effect, src)
	potentially_affecting = null

	if (master_NE)
		master_NE.lighting_corner_SW = null
		master_NE.lighting_corners_initialised = FALSE
	if (master_SE)
		master_SE.lighting_corner_NW = null
		master_SE.lighting_corners_initialised = FALSE
	if (master_SW)
		master_SW.lighting_corner_NE = null
		master_SW.lighting_corners_initialised = FALSE
	if (master_NW)
		master_NW.lighting_corner_SE = null
		master_NW.lighting_corners_initialised = FALSE
	if (needs_update)
		SSlighting.corners_queue -= src

	return ..()

/// Debug proc to aid in understanding how corners work
/datum/lighting_corner/proc/display(max_lum)
	if(QDELETED(src))
		return

	var/turf/draw_to = master_SW || master_NE || master_SE || master_NW
	var/mutable_appearance/display = mutable_appearance('icons/turf/debug.dmi', "corner_color", LIGHT_DEBUG_LAYER, draw_to, BALLOON_CHAT_PLANE)
	if(x > draw_to.x)
		display.pixel_x = 16
	else
		display.pixel_x = -16
	if(y > draw_to.y)
		display.pixel_y = 16
	else
		display.pixel_y = -16

	display.color = rgb(cache_r * 255, cache_g * 255, cache_b * 255)

	draw_to.add_overlay(display)

/datum/lighting_corner/dummy/display()
	return

/// Makes all lighting corners visible, debug to aid in understanding
/proc/display_corners()
	var/list/corners = list()
	var/max_lum = 0
	for(var/datum/lighting_corner/corner) // I am so sorry
		corners += corner
		max_lum = max(max_lum, corner.largest_color_luminosity)


	for(var/datum/lighting_corner/corner as anything in corners)
		corner.display(max_lum)
