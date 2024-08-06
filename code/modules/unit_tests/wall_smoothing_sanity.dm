/// Ensures tall walls don't partially smooth together (which would look like garbo)
/datum/unit_test/wall_smoothing_sanity

#warn pain
TEST_FOCUS(/datum/unit_test/wall_smoothing_sanity)

/datum/unit_test/wall_smoothing_sanity/Run()
	var/list/seen_targets = list()
	var/list/type_to_smoothing_info = list()
	for(var/turf/closed/smooth_wall_type as anything in typesof(/turf/closed))
		if(!initial(smooth_wall_type.use_splitvis))
			continue
		var/text_groups = initial(smooth_wall_type.smoothing_groups)
		var/text_targets = initial(smooth_wall_type.canSmoothWith)
		var/list/smoothing_groups = text_groups
		var/list/smoothing_targets = text_targets
		// convert them from strings to proper lists
		SET_SMOOTHING_GROUPS(smoothing_groups)
		SET_SMOOTHING_GROUPS(smoothing_targets)
		for(var/field in smoothing_targets)
			seen_targets[field] |= smoothing_targets[field]

		type_to_smoothing_info[smooth_wall_type] = list(smoothing_groups, smoothing_targets)

	var/list/problem_flags = list()
	for(var/turf/closed/smooth_wall_type as anything in type_to_smoothing_info)
		var/list/info = type_to_smoothing_info[smooth_wall_type]
		var/list/smoothing_groups = info[1]
		var/list/smoothing_targets = info[2]

		var/list/risky_flags = list()
		// check to see if anyone would ever smooth into us without us doing the same
		for(var/field in smoothing_groups)
			// Are there things we group with that we do not target
			if((smoothing_targets[field] & smoothing_groups[field]) == smoothing_groups[field])
				continue
			// find all the smoothing types we group with but do not target (that would target us)
			var/odd_flags = seen_targets[field] & (smoothing_groups[field] & ~(smoothing_targets[field]))
			if(odd_flags)
				risky_flags[field] |= odd_flags
		if(length(risky_flags))
			problem_flags[smooth_wall_type] = risky_flags

		var/failure = FALSE
		for(var/field in smoothing_targets)
			// Are there things we target that we don't group with
			if((smoothing_groups[field] & smoothing_targets[field]) == smoothing_targets[field])
				continue
			failure = TRUE
		if(failure)
			var/text_groups = encode_smoothing_groups(smoothing_groups)
			var/text_targets = encode_smoothing_groups(smoothing_targets)
			TEST_FAIL("[smooth_wall_type] smoothed with things it did not behave as (this risks smoothing into an unsmoothed wall). smoothing_groups: [text_groups] canSmoothWith: [text_targets]")

	if(!length(problem_flags))
		return

	for(var/turf/closed/smooth_wall_type as anything in type_to_smoothing_info)
		var/list/info = type_to_smoothing_info[smooth_wall_type]
		var/list/smoothing_groups = info[1]
		var/list/smoothing_targets = info[2]
		// Find all the types (by flag match) that we smooth with but do not reciprocate
		var/list/improper_targets = list()
		for(var/problem_type as anything in problem_flags)
			var/list/fucked_flags = list()
			var/list/problem_targets = problem_flags[problem_type]
			for(var/field in problem_targets)
				if(problem_targets[field] & smoothing_targets[field])
					fucked_flags[field] = problem_targets[field] & smoothing_targets[field]
			if(length(fucked_flags))
				improper_targets[encode_smoothing_groups(fucked_flags)] += list(problem_type)

		for(var/string_flags in improper_targets)
			var/text_groups = encode_smoothing_groups(smoothing_groups)
			var/text_targets = encode_smoothing_groups(smoothing_targets)
			var/list/target_types = improper_targets[string_flags]
			TEST_FAIL("[smooth_wall_type] has other walls that it smooths into that do not smooth into it. smoothing_groups: [text_groups], canSmoothWith: [text_targets], flags_at_issue: [string_flags], target_types: [json_encode(target_types)]")

