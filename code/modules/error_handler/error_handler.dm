GLOBAL_VAR_INIT(total_runtimes, GLOB.total_runtimes || 0)
GLOBAL_VAR_INIT(total_runtimes_skipped, 0)
// We get 30 lines of name text before byond cuts us off
// This needs to be short, but unique (with space for 8 chars to hold up to SHORT_REAL_LIMIT)
// So 22 chars. this is 21 for safety
#define EXCEPTION_SPECIAL_TEXT "___shr_cmx_ext_hdr___"
/// Max length of a name before byond cuts it off
#define BYOND_ERROR_HANDLING_NAME_LIMIT 30

/// For when you want to embed extra text about a /datum (won't work for atoms because we care about their name) in a stack trace
/// Keyed with a bit of text to replace (typically stored in the name), maps to a weakref to the datum to call render_for_errors() on
GLOBAL_LIST_EMPTY(exception_extensions)

/// Takes a datum to add runtime rendering for
/// Datum subtype MUST implement var/name as an untouched var, or this will not work at all
/proc/mark_complex_exception(datum/wants_more)
	var/static/uid = 1
	var/static/looped = FALSE

	if(looped)
		var/found_something = FALSE
		for(var/i in 1 to 1000) // You get 1k tries at finding an unused uid, assuming we've looped around after a few hours
			uid = WRAP(uid+1, 1, SHORT_REAL_LIMIT - 1)
			var/text = "[EXCEPTION_SPECIAL_TEXT][uid]"
			var/datum/weakref/existing = GLOB.exception_extensions[text]
			if(!existing?.hard_resolve()) // We've found an unused slot, take it
				found_something = TRUE
				break
		if(!found_something)
			return
	else
		if(uid >= SHORT_REAL_LIMIT - 1)
			uid = 1
			looped = TRUE
		else
			uid += 1
	var/text = "[EXCEPTION_SPECIAL_TEXT][uid]"
#ifdef UNIT_TESTS
	if(length(text) > BYOND_ERROR_HANDLING_NAME_LIMIT)
		stack_trace("[text], the uid for [wants_more.type]'s error rendering, was larger then byond's name limit ([BYOND_ERROR_HANDLING_NAME_LIMIT])")
		return
	if(length(EXCEPTION_SPECIAL_TEXT + SHORT_REAL_LIMIT))
		stack_trace("Our largest assumed uid is too large for ")
#endif
	wants_more:name = text
	GLOB.exception_extensions[text] = WEAKREF(wants_more)

/// Clears awaya complex exception, takes either a datum or the string key we were using
/// Again the datum must implement var/name or this WILL error
/proc/clear_complex_exception(remove)
	var/text = remove
	if(isdatum(remove))
		var/datum/datum_remove = remove
		text = datum_remove:name

	GLOB.exception_extensions -= text

/proc/process_complex_exceptions(text_to_render)
	var/static/regex/exception_lookup_regex = new("[EXCEPTION_SPECIAL_TEXT]\[0-9\]*", "g")
	// Passing a proc into a regex replace call will call it with each match, and replace with its return value
	return exception_lookup_regex.Replace(text_to_render, GLOBAL_PROC_REF(replace_text))

/// Takes text to replace, returns the replacement text
/proc/replace_text(key)
	var/datum/weakref/resolve_ref = GLOB.exception_extensions[key]
	if(!resolve_ref)
		return "{FULLY_DELETED_OBJECT}"
	// Hard resolve because I need this to work during destroys and such. DO NOT COPY THIS IS VERY SPOOKY
	var/datum/pull_from = resolve_ref.hard_resolve() // I mean it you fuck
	if(!pull_from)
		return "{FULLY_DELETED_OBJECT}"
	return pull_from.render_for_errors()

#ifdef USE_CUSTOM_ERROR_HANDLER
#define ERROR_USEFUL_LEN 2

/world/Error(exception/E, datum/e_src)
	GLOB.total_runtimes++

	if(!istype(E)) //Something threw an unusual exception
		log_world("uncaught runtime error: [E]")
		return ..()

	//this is snowflake because of a byond bug (ID:2306577), do not attempt to call non-builtin procs in this if
	if(copytext(E.name, 1, 32) == "Maximum recursion level reached")//32 == length() of that string + 1
		//log to world while intentionally triggering the byond bug.
		log_world("runtime error: [E.name]\n[E.desc]")
		//if we got to here without silently ending, the byond bug has been fixed.
		log_world("The bug with recursion runtimes has been fixed. Please remove the snowflake check from world/Error in [__FILE__]:[__LINE__]")
		return //this will never happen.

	else if(copytext(E.name, 1, 18) == "Out of resources!")//18 == length() of that string + 1
		log_world("BYOND out of memory. Restarting ([E?.file]:[E?.line])")
		TgsEndProcess()
		. = ..()
		Reboot(reason = 1)
		return

	var/static/list/error_last_seen = list()
	var/static/list/error_cooldown = list() /* Error_cooldown items will either be positive(cooldown time) or negative(silenced error)
												If negative, starts at -1, and goes down by 1 each time that error gets skipped*/
	// At the first safe oppertunity, we're gonna process the name/desc of the exception and replace out any complex exceptions
	E.name = process_complex_exceptions(E.name)
	E.desc = process_complex_exceptions(E.desc)

	if(!error_last_seen) // A runtime is occurring too early in start-up initialization
		return ..()

	var/erroruid = "[E.file][E.line]"
	var/last_seen = error_last_seen[erroruid]
	var/cooldown = error_cooldown[erroruid] || 0

	if(last_seen == null)
		error_last_seen[erroruid] = world.time
		last_seen = world.time

	if(cooldown < 0)
		error_cooldown[erroruid]-- //Used to keep track of skip count for this error
		GLOB.total_runtimes_skipped++
		return //Error is currently silenced, skip handling it
	//Handle cooldowns and silencing spammy errors
	var/silencing = FALSE

	// We can runtime before config is initialized because BYOND initialize objs/map before a bunch of other stuff happens.
	// This is a bunch of workaround code for that. Hooray!
	var/configured_error_cooldown
	var/configured_error_limit
	var/configured_error_silence_time
	if(config?.entries)
		configured_error_cooldown = CONFIG_GET(number/error_cooldown)
		configured_error_limit = CONFIG_GET(number/error_limit)
		configured_error_silence_time = CONFIG_GET(number/error_silence_time)
	else
		var/datum/config_entry/CE = /datum/config_entry/number/error_cooldown
		configured_error_cooldown = initial(CE.default)
		CE = /datum/config_entry/number/error_limit
		configured_error_limit = initial(CE.default)
		CE = /datum/config_entry/number/error_silence_time
		configured_error_silence_time = initial(CE.default)


	//Each occurence of a unique error adds to its cooldown time...
	cooldown = max(0, cooldown - (world.time - last_seen)) + configured_error_cooldown
	// ... which is used to silence an error if it occurs too often, too fast
	if(cooldown > configured_error_cooldown * configured_error_limit)
		cooldown = -1
		silencing = TRUE
		spawn(0)
			usr = null
			sleep(configured_error_silence_time)
			var/skipcount = abs(error_cooldown[erroruid]) - 1
			error_cooldown[erroruid] = 0
			if(skipcount > 0)
				SEND_TEXT(world.log, "\[[time_stamp()]] Skipped [skipcount] runtimes in [E.file],[E.line].")
				GLOB.error_cache.log_error(E, skip_count = skipcount)

	error_last_seen[erroruid] = world.time
	error_cooldown[erroruid] = cooldown

	var/list/usrinfo = null
	var/locinfo
	if(istype(usr))
		usrinfo = list("  usr: [key_name(usr)]")
		locinfo = loc_name(usr)
		if(locinfo)
			usrinfo += "  usr.loc: [locinfo]"
	// The proceeding mess will almost definitely break if error messages are ever changed
	var/list/splitlines = splittext(E.desc, "\n")
	var/list/desclines = list()
	if(LAZYLEN(splitlines) > ERROR_USEFUL_LEN) // If there aren't at least three lines, there's no info
		for(var/line in splitlines)
			if(LAZYLEN(line) < 3 || findtext(line, "source file:") || findtext(line, "usr.loc:"))
				continue
			if(findtext(line, "usr:"))
				if(usrinfo)
					desclines.Add(usrinfo)
					usrinfo = null
				continue // Our usr info is better, replace it

			if(copytext(line, 1, 3) != "  ")//3 == length("  ") + 1
				desclines += ("  " + line) // Pad any unpadded lines, so they look pretty
			else
				desclines += line
	if(usrinfo) //If this info isn't null, it hasn't been added yet
		desclines.Add(usrinfo)
	if(silencing)
		desclines += "  (This error will now be silenced for [DisplayTimeText(configured_error_silence_time)])"
	if(GLOB.error_cache)
		GLOB.error_cache.log_error(E, desclines)

	var/main_line = "\[[time_stamp()]] Runtime in [E.file],[E.line]: [E]"
	SEND_TEXT(world.log, main_line)
	for(var/line in desclines)
		SEND_TEXT(world.log, line)

#ifdef UNIT_TESTS
	if(GLOB.current_test)
		//good day, sir
		GLOB.current_test.Fail("[main_line]\n[desclines.Join("\n")]", file = E.file, line = E.line)
#endif


	// This writes the regular format (unwrapping newlines and inserting timestamps as needed).
	log_runtime("runtime error: [E.name]\n[E.desc]")
#endif

/// Describes how this datum should render when embedded in an error, assuming it has an id stored in GLOB.exception_extensions
/datum/proc/render_for_errors()
	return ""

#undef ERROR_USEFUL_LEN
