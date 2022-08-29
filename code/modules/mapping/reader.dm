///////////////////////////////////////////////////////////////
//SS13 Optimized Map loader
//////////////////////////////////////////////////////////////
#define SPACE_KEY "space"

/datum/grid_set
	var/xcrd
	var/ycrd
	var/zcrd
	var/gridLines

/datum/parsed_map
	var/original_path
	/// The length of a key in this file. This is promised by the standard to be static
	var/key_len = 0
	var/list/grid_models = list()
	var/list/gridSets = list()

	var/list/modelCache

	/// Unoffset bounds. Null on parse failure.
	var/list/parsed_bounds
	/// Offset bounds. Same as parsed_bounds until load().
	var/list/bounds

	///any turf in this list is skipped inside of build_coordinate
	var/list/turf_blacklist = list()

	// raw strings used to represent regexes more accurately
	// '' used to avoid confusing syntax highlighting
	var/static/regex/dmmRegex = new(@'"([a-zA-Z]+)" = \(((?:.|\n)*?)\)\n(?!\t)|\((\d+),(\d+),(\d+)\) = \{"([a-zA-Z\n]*)"\}', "g")
	var/static/regex/trimQuotesRegex = new(@'^[\s\n]+"?|"?[\s\n]+$|^"|"$', "g")
	var/static/regex/trimRegex = new(@'^[\s\n]+|[\s\n]+$', "g")

	#ifdef TESTING
	var/turfsSkipped = 0
	#endif

/// Shortcut function to parse a map and apply it to the world.
///
/// - `dmm_file`: A .dmm file to load (Required).
/// - `x_offset`, `y_offset`, `z_offset`: Positions representign where to load the map (Optional).
/// - `cropMap`: When true, the map will be cropped to fit the existing world dimensions (Optional).
/// - `measureOnly`: When true, no changes will be made to the world (Optional).
/// - `no_changeturf`: When true, [/turf/proc/AfterChange] won't be called on loaded turfs
/// - `x_lower`, `x_upper`, `y_lower`, `y_upper`: Coordinates (relative to the map) to crop to (Optional).
/// - `placeOnTop`: Whether to use [/turf/proc/PlaceOnTop] rather than [/turf/proc/ChangeTurf] (Optional).
/proc/load_map(dmm_file as file, x_offset as num, y_offset as num, z_offset as num, cropMap as num, measureOnly as num, no_changeturf as num, x_lower = -INFINITY as num, x_upper = INFINITY as num, y_lower = -INFINITY as num, y_upper = INFINITY as num, placeOnTop = FALSE as num)
	var/datum/parsed_map/parsed = new(dmm_file, x_lower, x_upper, y_lower, y_upper, measureOnly)
	if(parsed.bounds && !measureOnly)
		parsed.load(x_offset, y_offset, z_offset, cropMap, no_changeturf, x_lower, x_upper, y_lower, y_upper, placeOnTop)
	return parsed

/// Parse a map, possibly cropping it.
/datum/parsed_map/New(tfile, x_lower = -INFINITY, x_upper = INFINITY, y_lower = -INFINITY, y_upper=INFINITY, measureOnly=FALSE)
	// This proc sleeps for like 6 seconds. why?
	// Is it file accesses? if so, can those be done ahead of time, async to save on time here? I wonder.
	// Love ya :)
	if(isfile(tfile))
		original_path = "[tfile]"
		tfile = file2text(tfile)
	else if(isnull(tfile))
		// create a new datum without loading a map
		return

	src.bounds = parsed_bounds = list(1.#INF, 1.#INF, 1.#INF, -1.#INF, -1.#INF, -1.#INF)
	// lists are structs don't you know :)
	var/list/bounds = src.bounds
	var/list/grid_models = src.grid_models
	var/key_len = src.key_len

	var/stored_index = 1
	var/list/regexOutput
	//multiz lool
	while(dmmRegex.Find(tfile, stored_index))
		stored_index = dmmRegex.next
		// Datum var lookup is expensive, this isn't
		regexOutput = dmmRegex.group

		// "aa" = (/type{vars=blah})
		if(regexOutput[1]) // Model
			var/key = regexOutput[1]
			if(grid_models[key]) // Duplicate model keys are ignored in DMMs
				continue
			if(key_len != length(key))
				if(!key_len)
					key_len = length(key)
				else
					CRASH("Inconsistent key length in DMM")
			if(!measureOnly)
				grid_models[key] = regexOutput[2]

		// (1,1,1) = {"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
		else if(regexOutput[3]) // Coords
			if(!key_len)
				CRASH("Coords before model definition in DMM")

			var/curr_x = text2num(regexOutput[3])

			if(curr_x < x_lower || curr_x > x_upper)
				continue

			var/datum/grid_set/gridSet = new

			gridSet.xcrd = curr_x
			//position of the currently processed square
			gridSet.ycrd = text2num(regexOutput[4])
			gridSet.zcrd = text2num(regexOutput[5])

			bounds[MAP_MINX] = min(bounds[MAP_MINX], curr_x)
			bounds[MAP_MINZ] = min(bounds[MAP_MINZ], gridSet.zcrd)
			bounds[MAP_MAXZ] = max(bounds[MAP_MAXZ], gridSet.zcrd)

			var/list/gridLines = splittext(regexOutput[6], "\n")
			gridSet.gridLines = gridLines

			var/leadingBlanks = 0
			while(leadingBlanks < length(gridLines) && gridLines[++leadingBlanks] == "")
			if(leadingBlanks > 1)
				gridLines.Cut(1, leadingBlanks) // Remove all leading blank lines.

			if(!length(gridLines)) // Skip it if only blank lines exist.
				continue

			gridSets += gridSet

			if(gridLines[length(gridLines)] == "")
				gridLines.Cut(length(gridLines)) // Remove only one blank line at the end.

			bounds[MAP_MINY] = min(bounds[MAP_MINY], gridSet.ycrd)
			gridSet.ycrd += length(gridLines) - 1 // Start at the top and work down
			bounds[MAP_MAXY] = max(bounds[MAP_MAXY], gridSet.ycrd)

			var/maxx = curr_x
			if(length(gridLines)) //Not an empty map
				maxx = max(maxx, curr_x + length(gridLines[1]) / key_len - 1)

			bounds[MAP_MAXX] = max(bounds[MAP_MAXX], maxx)
		CHECK_TICK

	// Indicate failure to parse any coordinates by nulling bounds
	if(bounds[1] == 1.#INF)
		src.bounds = null
	else
		// Clamp all our mins and maxes down to the proscribed limits
		bounds[MAP_MINX] = clamp(bounds[MAP_MINX], x_lower, x_upper)
		bounds[MAP_MAXX] = clamp(bounds[MAP_MAXX], x_lower, x_upper)
		bounds[MAP_MINY] = clamp(bounds[MAP_MINY], y_lower, y_upper)
		bounds[MAP_MAXY] = clamp(bounds[MAP_MAXY], y_lower, y_upper)

	parsed_bounds = src.bounds
	src.key_len = key_len

/// Load the parsed map into the world. See [/proc/load_map] for arguments.
/datum/parsed_map/proc/load(x_offset, y_offset, z_offset, cropMap, no_changeturf, x_lower, x_upper, y_lower, y_upper, placeOnTop, whitelist = FALSE)
	if(!whitelist)
		return
	//How I wish for RAII
	Master.StartLoadingMap()
	. = _load_impl(x_offset, y_offset, z_offset, cropMap, no_changeturf, x_lower, x_upper, y_lower, y_upper, placeOnTop)
	Master.StopLoadingMap()

GLOBAL_LIST_EMPTY(load_costs)
GLOBAL_LIST_EMPTY(load_counts)
//#define SET_COST(category)
// Do not call except via load() above.
/datum/parsed_map/proc/_load_impl(x_offset = 1, y_offset = 1, z_offset = world.maxz + 1, cropMap = FALSE, no_changeturf = FALSE, x_lower = -INFINITY, x_upper = INFINITY, y_lower = -INFINITY, y_upper = INFINITY, placeOnTop = FALSE)
	PRIVATE_PROC(TRUE)
	var/list/modelCache = build_cache(no_changeturf)
	var/list/areaCache = list()
	var/space_key = modelCache[SPACE_KEY]
	var/list/bounds
	var/key_len = src.key_len
	src.bounds = bounds = list(1.#INF, 1.#INF, 1.#INF, -1.#INF, -1.#INF, -1.#INF)

	//used for sending the maxx and maxy expanded global signals at the end of this proc
	var/has_expanded_world_maxx = FALSE
	var/has_expanded_world_maxy = FALSE
	var/y_relative_to_absolute = y_offset - 1
	var/x_relative_to_absolute = x_offset - 1
	for(var/datum/grid_set/gset as anything in gridSets)
		var/relative_x = gset.xcrd
		var/relative_y = gset.ycrd
		var/true_xcrd = relative_x + x_relative_to_absolute
		var/ycrd = relative_y + y_relative_to_absolute
		var/zcrd = gset.zcrd + z_offset - 1
		if(!cropMap && ycrd > world.maxy)
			world.maxy = ycrd // Expand Y here.  X is expanded in the loop below
			has_expanded_world_maxy = TRUE
		var/zexpansion = zcrd > world.maxz
		var/no_afterchange = no_changeturf
		if(zexpansion)
			if(cropMap)
				continue
			else
				while (zcrd > world.maxz) //create a new z_level if needed
					world.incrementMaxZ()
			if(!no_changeturf)
				WARNING("Z-level expansion occurred without no_changeturf set, this may cause problems when /turf/AfterChange is called")
				no_afterchange = TRUE
		// Ok so like. something important
		// We talk in "relative" coords here, so the coordinate system of the map datum
		// This is so we can do offsets, but it is NOT the same as positions in game
		// That's why there's some uses of - y_relative_to_absolute here, to turn absolute positions into relative ones

		// Skip Y coords that are above the smallest of the three params
		// So maxy and y_upper get to act as thresholds, and relative_y can play
		var/y_skip_above = min(world.maxy - y_relative_to_absolute, y_upper, relative_y)
		// How many lines to skip because they'd be above the y cuttoff line
		var/y_starting_skip = relative_y - y_skip_above
		ycrd += y_starting_skip

		// Y is the LOWEST it will ever be here, so we can easily set a threshold for how low to go
		var/line_count = length(gset.gridLines)
		var/lowest_y = relative_y - line_count
		var/y_skip_below = max(1 - y_relative_to_absolute, y_lower, lowest_y)
		var/y_ending_skip = y_skip_below - lowest_y

		// Now we're gonna precompute the x thresholds
		// We skip all the entries below the lower y, or 1
		var/starting_x_delta = max(max(x_lower, 1 - x_relative_to_absolute) - relative_x, 0)
		// The x loop counts by key length, so we gotta multiply here
		var/x_starting_skip = starting_x_delta * key_len
		true_xcrd += starting_x_delta

		var/line_length = 0
		if(line_count)
			// This is promised as static, so we will treat it as such
			line_length = length(gset.gridLines[1])
		// We're gonna skip all the entries above the upper x, or maxx if cropMap is set
		var/x_target = line_length - key_len + 1
		var/x_step_count = ROUND_UP(x_target / key_len)
		var/final_x = relative_x + (x_step_count - 1)
		var/x_delta_with = x_upper
		if(cropMap)
			// Take our smaller crop threshold yes?
			x_delta_with = min(x_delta_with, world.maxx)
		if(final_x > x_delta_with)
			// If our relative x is greater then X upper, well then we've gotta limit our expansion
			var/delta = max(final_x - x_delta_with, 0)
			x_step_count -= delta
			final_x -= delta
			x_target = x_step_count * key_len
		if(final_x > world.maxx && !cropMap)
			world.maxx = final_x
			has_expanded_world_maxx = TRUE

		// We're gonna track the first and last pairs of coords we find
		// The first x is guarenteed to be the lowest, the first y the highest, and vis versa
		// This is faster then doing mins and maxes inside the hot loop below
		var/first_found = FALSE
		var/first_x = 0
		var/first_y = 0
		var/last_x = 0
		var/last_y = 0

		// Everything following this line is VERY hot. How hot depends on the map format
		// (Yes this does mean dmm is technically faster to parse. shut up)

		// This is the "is this map tgm" check
		if(key_len == line_length)
			// Wanna clear something up about maps, talking in 255x255 here
			// In the tgm format, each gridset contains 255 lines, each line representing one tile, with 255 total gridsets
			// In the dmm format, each gridset contains 255 lines, each line representing one row of tiles, containing 255 * line length characters, with one gridset per z
			// since this is the tgm branch any cutoff of x means we just shouldn't iterate this gridset
			if(!x_step_count || x_starting_skip)
				continue
			for(var/i in 1 + y_starting_skip to line_count - y_ending_skip)
				var/line = gset.gridLines[i]
				if(line == space_key && no_afterchange)
					#ifdef TESTING
						++turfsSkipped
					#endif
					ycrd--
					//CHECK_TICK
					continue

				var/list/cache = modelCache[line]
				if(!cache)
					CRASH("Undefined model key in DMM: [line]")
				build_coordinate(areaCache, cache, locate(true_xcrd, ycrd, zcrd), no_afterchange, placeOnTop)

				// only bother with bounds that actually exist
				if(!first_found)
					first_found = TRUE
					first_y = ycrd
				last_y = ycrd
				ycrd--
				//CHECK_TICK
			// The x coord never changes, so this is safe
			if(first_found)
				first_x = true_xcrd
		else
			// This is the dmm parser, note the double loop
			for(var/i in 1 + y_starting_skip to line_count - y_ending_skip)
				var/line = gset.gridLines[i]

				var/xcrd = true_xcrd
				for(var/tpos in 1 + x_starting_skip to x_target step key_len)
					var/model_key = copytext(line, tpos, tpos + key_len)
					if(model_key == space_key && no_afterchange)
						#ifdef TESTING
							++turfsSkipped
						#endif
						//CHECK_TICK
						++xcrd
						continue
					var/list/cache = modelCache[model_key]
					if(!cache)
						CRASH("Undefined model key in DMM: [model_key]")
					build_coordinate(areaCache, cache, locate(xcrd, ycrd, zcrd), no_afterchange, placeOnTop)

					// only bother with bounds that actually exist
					if(!first_found)
						first_found = TRUE
						first_x = xcrd
						first_y = ycrd
					last_x = xcrd
					last_y = ycrd
					//CHECK_TICK
					++xcrd
				ycrd--
				CHECK_TICK
		bounds[MAP_MINX] = min(bounds[MAP_MINX], first_x)
		bounds[MAP_MAXX] = max(bounds[MAP_MAXX], last_x)
		bounds[MAP_MINY] = min(bounds[MAP_MINY], last_y)
		bounds[MAP_MAXY] = max(bounds[MAP_MAXY], first_y)
		bounds[MAP_MINZ] = min(bounds[MAP_MINZ], zcrd)
		bounds[MAP_MAXZ] = max(bounds[MAP_MAXZ], zcrd)

	if(!no_changeturf)
		for(var/turf/T as anything in block(locate(bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ]), locate(bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ])))
			//we do this after we load everything in. if we don't; we'll have weird atmos bugs regarding atmos adjacent turfs
			T.AfterChange(CHANGETURF_IGNORE_AIR)

	if(has_expanded_world_maxx || has_expanded_world_maxy)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPANDED_WORLD_BOUNDS, has_expanded_world_maxx, has_expanded_world_maxy)

	#ifdef TESTING
	if(turfsSkipped)
		testing("Skipped loading [turfsSkipped] default turfs")
	#endif

	return TRUE

/datum/parsed_map/proc/build_cache(no_changeturf, bad_paths=null)
	if(modelCache && !bad_paths)
		return modelCache
	. = modelCache = list()
	var/list/grid_models = src.grid_models
	for(var/model_key in grid_models)
		var/model = grid_models[model_key]
		var/list/members = list() //will contain all members (paths) in model (in our example : /turf/unsimulated/wall and /area/mine/explored)
		var/list/members_attributes = list() //will contain lists filled with corresponding variables, if any (in our example : list(icon_state = "rock") and list())

		/////////////////////////////////////////////////////////
		//Constructing members and corresponding variables lists
		////////////////////////////////////////////////////////

		var/index = 1
		var/old_position = 1
		var/dpos

		while(dpos != 0)
			//finding next member (e.g /turf/unsimulated/wall{icon_state = "rock"} or /area/mine/explored)
			dpos = find_next_delimiter_position(model, old_position, ",", "{", "}") //find next delimiter (comma here) that's not within {...}

			var/full_def = trim_text(copytext(model, old_position, dpos)) //full definition, e.g : /obj/foo/bar{variables=derp}
			var/variables_start = findtext(full_def, "{")
			var/path_text = trim_text(copytext(full_def, 1, variables_start))
			var/atom_def = text2path(path_text) //path definition, e.g /obj/foo/bar
			if(dpos)
				old_position = dpos + length(model[dpos])

			if(!ispath(atom_def, /atom)) // Skip the item if the path does not exist.  Fix your crap, mappers!
				if(bad_paths)
					LAZYOR(bad_paths[path_text], model_key)
				continue
			members.Add(atom_def)

			//transform the variables in text format into a list (e.g {var1="derp"; var2; var3=7} => list(var1="derp", var2, var3=7))
			var/list/fields = list()

			if(variables_start)//if there's any variable
				full_def = copytext(full_def, variables_start + length(full_def[variables_start]), -length(copytext_char(full_def, -1))) //removing the last '}'
				fields = readlist(full_def, ";")
				if(fields.len)
					if(!trim(fields[fields.len]))
						--fields.len
					for(var/I in fields)
						var/value = fields[I]
						if(istext(value))
							fields[I] = apply_text_macros(value)

			//then fill the members_attributes list with the corresponding variables
			members_attributes.len++
			members_attributes[index++] = fields

			//CHECK_TICK

		//check and see if we can just skip this turf
		//So you don't have to understand this horrid statement, we can do this if
		// 1. no_changeturf is set
		// 2. the space_key isn't set yet
		// 3. there are exactly 2 members
		// 4. with no attributes
		// 5. and the members are world.turf and world.area
		// Basically, if we find an entry like this: "XXX" = (/turf/default, /area/default)
		// We can skip calling this proc every time we see XXX
		if(no_changeturf \
			&& !(.[SPACE_KEY]) \
			&& members.len == 2 \
			&& members_attributes.len == 2 \
			&& length(members_attributes[1]) == 0 \
			&& length(members_attributes[2]) == 0 \
			&& (world.area in members) \
			&& (world.turf in members))

			.[SPACE_KEY] = model_key
			continue


		.[model_key] = list(members, members_attributes)

/datum/parsed_map/proc/build_coordinate(list/areaCache, list/model, turf/crds, no_changeturf as num, placeOnTop as num)
	var/index
	var/list/members = model[1]
	var/list/members_attributes = model[2]

	////////////////
	//Instanciation
	////////////////

	for (var/turf_in_blacklist in turf_blacklist)
		if (crds == turf_in_blacklist) //if the given turf is blacklisted, dont do anything with it
			return

	//The next part of the code assumes there's ALWAYS an /area AND a /turf on a given tile
	//first instance the /area and remove it from the members list
	index = members.len
	if(members[index] != /area/template_noop)
		var/atype = members[index]
		world.preloader_setup(members_attributes[index], atype)//preloader for assigning  set variables on atom creation
		var/atom/instance = areaCache[atype]
		if (!instance)
			instance = GLOB.areas_by_type[atype]
			if (!instance)
				instance = new atype(null)
			areaCache[atype] = instance
		if(crds)
			instance.contents.Add(crds)

		if(GLOB.use_preloader && instance)
			world.preloader_load(instance)

	//then instance the /turf and, if multiple tiles are presents, simulates the DMM underlays piling effect

	var/first_turf_index = 1
	while(!ispath(members[first_turf_index], /turf)) //find first /turf object in members
		first_turf_index++

	//turn off base new Initialization until the whole thing is loaded
	SSatoms.map_loader_begin()
	//instanciate the first /turf
	var/turf/T
	if(members[first_turf_index] != /turf/template_noop)
		T = instance_atom(members[first_turf_index],members_attributes[first_turf_index],crds,no_changeturf,placeOnTop)

	if(T)
		//if others /turf are presents, simulates the underlays piling effect
		index = first_turf_index + 1
		while(index <= members.len - 1) // Last item is an /area
			var/underlay = T.appearance
			T = instance_atom(members[index],members_attributes[index],crds,no_changeturf,placeOnTop)//instance new turf
			T.underlays += underlay
			index++

	//finally instance all remainings objects/mobs
	for(index in 1 to first_turf_index-1)
		instance_atom(members[index],members_attributes[index],crds,no_changeturf,placeOnTop)
	//Restore initialization to the previous value
	SSatoms.map_loader_stop()

////////////////
//Helpers procs
////////////////

//Instance an atom at (x,y,z) and gives it the variables in attributes
/datum/parsed_map/proc/instance_atom(path,list/attributes, turf/crds, no_changeturf, placeOnTop)
	world.preloader_setup(attributes, path)

	if(crds)
		if(ispath(path, /turf))
			if(placeOnTop)
				. = crds.PlaceOnTop(null, path, CHANGETURF_DEFER_CHANGE | (no_changeturf ? CHANGETURF_SKIP : NONE))
			else if(!no_changeturf)
				. = crds.ChangeTurf(path, null, CHANGETURF_DEFER_CHANGE)
			else
				. = create_atom(path, crds)//first preloader pass
		else
			. = create_atom(path, crds)//first preloader pass

	if(GLOB.use_preloader && .)//second preloader pass, for those atoms that don't ..() in New()
		world.preloader_load(.)

	//custom CHECK_TICK here because we don't want things created while we're sleeping to not initialize
	//if(TICK_CHECK)
		//SSatoms.map_loader_stop()
		//stoplag()
		//SSatoms.map_loader_begin()

/datum/parsed_map/proc/create_atom(path, crds)
	set waitfor = FALSE
	. = new path (crds)

//text trimming (both directions) helper proc
//optionally removes quotes before and after the text (for variable name)
/datum/parsed_map/proc/trim_text(what as text,trim_quotes=0)
	if(trim_quotes)
		return trimQuotesRegex.Replace(what, "")
	else
		return trimRegex.Replace(what, "")


//find the position of the next delimiter,skipping whatever is comprised between opening_escape and closing_escape
//returns 0 if reached the last delimiter
/datum/parsed_map/proc/find_next_delimiter_position(text as text,initial_position as num, delimiter=",",opening_escape="\"",closing_escape="\"")
	var/position = initial_position
	var/next_delimiter = findtext(text,delimiter,position,0)
	var/next_opening = findtext(text,opening_escape,position,0)

	while((next_opening != 0) && (next_opening < next_delimiter))
		position = findtext(text,closing_escape,next_opening + 1,0)+1
		next_delimiter = findtext(text,delimiter,position,0)
		next_opening = findtext(text,opening_escape,position,0)

	return next_delimiter


//build a list from variables in text form (e.g {var1="derp"; var2; var3=7} => list(var1="derp", var2, var3=7))
//return the filled list
/datum/parsed_map/proc/readlist(text as text, delimiter=",")
	. = list()
	if (!text)
		return

	var/position
	var/old_position = 1

	while(position != 0)
		// find next delimiter that is not within  "..."
		position = find_next_delimiter_position(text,old_position,delimiter)

		// check if this is a simple variable (as in list(var1, var2)) or an associative one (as in list(var1="foo",var2=7))
		var/equal_position = findtext(text,"=",old_position, position)

		var/trim_left = trim_text(copytext(text,old_position,(equal_position ? equal_position : position)))
		var/left_constant = delimiter == ";" ? trim_left : parse_constant(trim_left)
		if(position)
			old_position = position + length(text[position])

		if(equal_position && !isnum(left_constant))
			// Associative var, so do the association.
			// Note that numbers cannot be keys - the RHS is dropped if so.
			var/trim_right = trim_text(copytext(text, equal_position + length(text[equal_position]), position))
			var/right_constant = parse_constant(trim_right)
			.[left_constant] = right_constant

		else  // simple var
			. += list(left_constant)

/datum/parsed_map/proc/parse_constant(text)
	// number
	var/num = text2num(text)
	if(isnum(num))
		return num

	// string
	if(text[1] == "\"")
		return copytext(text, length(text[1]) + 1, findtext(text, "\"", length(text[1]) + 1))

	// list
	if(copytext(text, 1, 6) == "list(")//6 == length("list(") + 1
		return readlist(copytext(text, 6, -1))

	// typepath
	var/path = text2path(text)
	if(ispath(path))
		return path

	// file
	if(text[1] == "'")
		return file(copytext_char(text, 2, -1))

	// null
	if(text == "null")
		return null

	// not parsed:
	// - pops: /obj{name="foo"}
	// - new(), newlist(), icon(), matrix(), sound()

	// fallback: string
	return text

/datum/parsed_map/Destroy()
	..()
	turf_blacklist.Cut()
	parsed_bounds.Cut()
	bounds.Cut()
	grid_models.Cut()
	gridSets.Cut()
	return QDEL_HINT_HARDDEL_NOW
