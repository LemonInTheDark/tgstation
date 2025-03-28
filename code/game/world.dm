#define RESTART_COUNTER_PATH "data/round_counter.txt"
/// Load byond-tracy. If USE_BYOND_TRACY is defined, then this is ignored and byond-tracy is always loaded.
#define USE_TRACY_PARAMETER "tracy"
/// Force the log directory to be something specific in the data/logs folder
#define OVERRIDE_LOG_DIRECTORY_PARAMETER "log-directory"
/// Prevent the master controller from starting automatically
#define NO_INIT_PARAMETER "no-init"

GLOBAL_VAR(restart_counter)
GLOBAL_VAR(tracy_log)
GLOBAL_PROTECT(tracy_log)
GLOBAL_VAR(tracy_initialized)
GLOBAL_PROTECT(tracy_initialized)
GLOBAL_VAR(tracy_init_error)
GLOBAL_PROTECT(tracy_init_error)
GLOBAL_VAR(tracy_init_reason)
GLOBAL_PROTECT(tracy_init_reason)

/**
 * WORLD INITIALIZATION
 * THIS IS THE INIT ORDER:
 *
 * BYOND =>
 * - (secret init native) =>
 *   - world.Genesis() =>\
 *     - world.unroll_cpu_value()
 *     - world.init_byond_tracy()
 *     - (Start native profiling)
 *     - world.init_debugger()
 *     - Master =>
 *       - config *unloaded
 *       - (all subsystems) PreInit()
 *       - GLOB =>
 *         - make_datum_reference_lists()
 *   - (/static variable inits, reverse declaration order)
 * - (all pre-mapped atoms) /atom/New()
 * - world.New() =>
 *   - config.Load()
 *   - world.InitTgs() =>
 *     - TgsNew() *may sleep
 *     - GLOB.rev_data.load_tgs_info()
 *   - world.ConfigLoaded() =>
 *     - SSdbcore.InitializeRound()
 *     - world.SetupLogs()
 *     - load_admins()
 *     - ...
 *   - Master.Initialize() =>
 *     - (all subsystems) Initialize()
 *     - Master.StartProcessing() =>
 *       - Master.Loop() =>
 *         - Failsafe
 *   - world.RunUnattendedFunctions()
 *
 * Now listen up because I want to make something clear:
 * If something is not in this list it should almost definitely be handled by a subsystem Initialize()ing
 * If whatever it is that needs doing doesn't fit in a subsystem you probably aren't trying hard enough tbhfam
 *
 * GOT IT MEMORIZED?
 * - Dominion/Cyberboss
 *
 * Where to put init shit quick guide:
 * If you need it to happen before the mc is created: world/Genesis.
 * If you need it to happen last: world/New(),
 * Otherwise, in a subsystem preinit or init. Subsystems can set an init priority.
 */

/**
 * THIS !!!SINGLE!!! PROC IS WHERE ANY FORM OF INIITIALIZATION THAT CAN'T BE PERFORMED IN SUBSYSTEMS OR WORLD/NEW IS DONE
 * NOWHERE THE FUCK ELSE
 * I DON'T CARE HOW MANY LAYERS OF DEBUG/PROFILE/TRACE WE HAVE, YOU JUST HAVE TO DEAL WITH THIS PROC EXISTING
 * I'M NOT EVEN GOING TO TELL YOU WHERE IT'S CALLED FROM BECAUSE I'M DECLARING THAT FORBIDDEN KNOWLEDGE
 * SO HELP ME GOD IF I FIND ABSTRACTION LAYERS OVER THIS!
 */
/world/proc/Genesis(tracy_initialized = FALSE)
	RETURN_TYPE(/datum/controller/master)

	unroll_cpu_value()
	if(!tracy_initialized)
		GLOB.tracy_initialized = FALSE
#ifndef OPENDREAM
	if(!tracy_initialized)
#ifdef USE_BYOND_TRACY
#warn USE_BYOND_TRACY is enabled
		var/should_init_tracy = TRUE
		GLOB.tracy_init_reason = "USE_BYOND_TRACY defined"
#else
		var/should_init_tracy = FALSE
		if(USE_TRACY_PARAMETER in params)
			should_init_tracy = TRUE
			GLOB.tracy_init_reason = "world.params"
		if(fexists(TRACY_ENABLE_PATH))
			GLOB.tracy_init_reason ||= "enabled for round"
			SEND_TEXT(world.log, "[TRACY_ENABLE_PATH] exists, initializing byond-tracy!")
			should_init_tracy = TRUE
			fdel(TRACY_ENABLE_PATH)
#endif
		if(should_init_tracy)
			init_byond_tracy()
			Genesis(tracy_initialized = TRUE)
			return
#endif
	Profile(PROFILE_RESTART)
	Profile(PROFILE_RESTART, type = "sendmaps")

	// Write everything to this log file until we get to SetupLogs() later
	_initialize_log_files("data/logs/config_error.[GUID()].log")

	// Init the debugger first so we can debug Master
	init_debugger()

	// Create the logger
	logger = new

	// THAT'S IT, WE'RE DONE, THE. FUCKING. END.
	Master = new
	____tick_info.pain += "NEW [TICK_USAGE]"

/**
 * World creation
 *
 * Here is where a round itself is actually begun and setup.
 * * db connection setup
 * * config loaded from files
 * * loads admins
 * * Sets up the dynamic menu system
 * * and most importantly, calls initialize on the master subsystem, starting the game loop that causes the rest of the game to begin processing and setting up
 *
 *
 * Nothing happens until something moves. ~Albert Einstein
 *
 * For clarity, this proc gets triggered later in the initialization pipeline, it is not the first thing to happen, as it might seem.
 *
 * Initialization Pipeline:
 * Global vars are new()'ed, (including config, glob, and the master controller will also new and preinit all subsystems when it gets new()ed)
 * Compiled in maps are loaded (mainly centcom). all areas/turfs/objs/mobs(ATOMs) in these maps will be new()ed
 * world/New() (You are here)
 * Once world/New() returns, client's can connect.
 * 1 second sleep
 * Master Controller initialization.
 * Subsystem initialization.
 * Non-compiled-in maps are maploaded, all atoms are new()ed
 * All atoms in both compiled and uncompiled maps are initialized()
 */
/world/New()
	log_world("World loaded at [time_stamp()]!")

	// From a really fucking old commit (91d7150)
	// I wanted to move it but I think this needs to be after /world/New is called but before any sleeps?
	// - Dominion/Cyberboss
	GLOB.timezoneOffset = world.timezone * 36000
	____tick_info.pain += "NEW [TICK_USAGE]"
	// First possible sleep()
	InitTgs()
	____tick_info.pain += "TGS [TICK_USAGE]"

	config.Load(params[OVERRIDE_CONFIG_DIRECTORY_PARAMETER])

	ConfigLoaded()

	if(NO_INIT_PARAMETER in params)
		return
	____tick_info.pain += "CONFIG [TICK_USAGE]"

	Master.Initialize(10, FALSE, TRUE)
	____tick_info.pain += "MASTER [TICK_USAGE]"

	RunUnattendedFunctions()
	____tick_info.pain += "RUN_UNATTENDED [TICK_USAGE]"
	____tick_info.logged_tick_late = TICK_USAGE

#define CPU_SIZE 16
#define WINDOW_SIZE 16
#define FORMAT_CPU(cpu) round(cpu, 0.01)

// Should we intentionally consume cpu time to try to keep SendMaps deltas constant?
GLOBAL_VAR_INIT(attempt_corrective_cpu, FALSE)
// Debug tool, lets us set the floor of cpu consumption
GLOBAL_VAR_INIT(floor_cpu, 0)
// Debug tool, lets us set a sometimes used floor for cpu consumption
GLOBAL_VAR_INIT(sustain_cpu, 0)
// Debug tool, sets the chance to use GLOB.sustain_cpu as a floor
GLOBAL_VAR_INIT(sustain_cpu_chance, 0)
// Debug tool, floors cpu to its value, then resets itself
GLOBAL_VAR_INIT(spike_cpu, 0)

/world/Tick()
	unroll_cpu_value()
	if(GLOB.floor_cpu)
		// avoids byond sleeping the loop and causing the MC to infinistall
		// Run first to set a floor for sustain to spike up to
		CONSUME_UNTIL(min(GLOB.floor_cpu, 500))

	if(GLOB.sustain_cpu && prob(GLOB.sustain_cpu_chance))
		CONSUME_UNTIL(min(GLOB.sustain_cpu, 500))

	if(GLOB.spike_cpu)
		CONSUME_UNTIL(min(GLOB.spike_cpu, 10000))
		GLOB.spike_cpu = 0

	// attempt to correct cpu overrun
	if(GLOB.attempt_corrective_cpu)
		CONSUME_UNTIL(TICK_EXPECTED_SAFE_MAX)
	GLOB.cpu_tracker.update_display()
	// this is for next tick so don't display it yet yeah?
	var/datum/tick_holder/tick_info = ____tick_info
	tick_info.tick_cpu_usage[WRAP(tick_info.cpu_index, 1, CPU_SIZE + 1)] = TICK_USAGE

GLOBAL_DATUM_INIT(cpu_tracker, /atom/movable/screen/usage_display, new())

/atom/movable/screen/usage_display
	screen_loc = "LEFT:8, CENTER"
	plane = CPU_DEBUG_PLANE
	maptext_width = 256
	maptext_height = 512
	alpha = 220
	clear_with_screen = FALSE
	// how many people are looking at us right now?
	var/viewer_count = 0

/atom/movable/screen/usage_display/proc/update_display()
	if(viewer_count <= 0)
		return
	var/datum/tick_holder/tick_info = GLOB.tick_info
	var/list/cpu_values = tick_info.cpu_values
	var/list/verb_cost = tick_info.verb_cost
	var/last_index = WRAP(tick_info.cpu_index - 1, 1, CPU_SIZE + 1)
	var/full_time = TICKS2DS(CPU_SIZE) / 10 // convert from ticks to seconds
	maptext = "<div style=\"background-color:#FFFFFF; color:#000000;\">\
		Toggles: <a href='byond://?src=[REF(src)];act=toggle_movement'>New Glide [GLOB.use_new_glide]</a> <a href='byond://?src=[REF(src)];act=toggle_compensation'>CPU Compensation [GLOB.attempt_corrective_cpu]</a> <a href='byond://?src=[REF(src)];act=catch_negatives'>Catch Negatives [GLOB.negative_printed]</a>\n\
		Queue Control: <a href='byond://?src=[REF(src)];act=clamp_queue'>CLAMP</a> <a href='byond://?src=[REF(src)];act=flush_queue'>FLUSH</a>\n\
		Glide: New ([GLOB.glide_size_multiplier]) Old ([GLOB.old_glide_size_multiplier])\n\
		Floor: <a href='byond://?src=[REF(src)];act=set_floor'>[GLOB.floor_cpu]</a>\n\
		Sustain: <a href='byond://?src=[REF(src)];act=set_sustain_cpu'>[GLOB.sustain_cpu]</a> <a href='byond://?src=[REF(src)];act=set_sustain_chance'>[GLOB.sustain_cpu_chance]%</a>\n\
		Spike: <a href='byond://?src=[REF(src)];act=set_spike'>[GLOB.spike_cpu]</a>\n\
		Tick: [FORMAT_CPU(world.time / world.tick_lag)]\n\
		Frame Behind ~CPU: [FORMAT_CPU(cpu_values[last_index])]\n\
		Frame Behind Tick: [FORMAT_CPU(tick_info.tick_cpu_usage[last_index])]\n\
		Frame Behind Map Cpu: [FORMAT_CPU(world.map_cpu)]\n\
		Frame Behind ~Verb: [FORMAT_CPU(verb_cost[last_index])]\n\
		<div style=\"color:#FF0000;\">\
			Max ~CPU [full_time]s: [FORMAT_CPU(max(cpu_values))]\n\
			Max Tick [full_time]s: [FORMAT_CPU(max(tick_info.tick_cpu_usage))]\n\
			Max Map [full_time]s: [FORMAT_CPU(max(tick_info.map_cpu_usage))]\n\
			Max ~Verb [full_time]s: [FORMAT_CPU(max(verb_cost))]\n\
		</div>\
		<div style=\"color:#0096FF;\">\
			Min ~CPU [full_time]s: [FORMAT_CPU(min(cpu_values))]\n\
			Min Tick [full_time]s: [FORMAT_CPU(min(tick_info.tick_cpu_usage))]\n\
			Min Map [full_time]s: [FORMAT_CPU(min(tick_info.map_cpu_usage))]\n\
			Min ~Verb [full_time]s: [FORMAT_CPU(min(verb_cost))]\
		</div>\n\
		CPU Drift Max: [FORMAT_CPU(max(tick_info.cpu_error))]\n\
		CPU Drift Min: [FORMAT_CPU(min(tick_info.cpu_error))]\
	</div>"


/atom/movable/screen/usage_display/proc/toggle_cpu_debug(client/modify)
	if(modify?.displaying_cpu_debug) // I am lazy and this is a cold path
		viewer_count -= 1
		modify.screen -= src
		UnregisterSignal(modify, COMSIG_QDELETING)
		modify?.displaying_cpu_debug = FALSE
	else
		viewer_count += 1
		modify.screen += src
		RegisterSignal(modify, COMSIG_QDELETING, PROC_REF(client_disconnected))
		modify?.displaying_cpu_debug = TRUE
		if(viewer_count == 1)
			update_display()

	for(var/atom/movable/screen/plane_master/cpu_debug/debuggin as anything in modify.mob?.hud_used?.get_true_plane_masters(CPU_DEBUG_PLANE))
		debuggin.update_visibility(modify.mob)

/atom/movable/screen/usage_display/proc/client_disconnected(client/disconnected)
	SIGNAL_HANDLER
	toggle_cpu_debug(disconnected)

/atom/movable/screen/usage_display/Topic(href, list/href_list)
	if (..())
		return
	if(!check_rights(R_DEBUG) || !check_rights(R_SERVER))
		return FALSE
	var/datum/tick_holder/tick_info = GLOB.tick_info
	switch(href_list["act"])
		if("flush_queue") // last resort for testing, sets queue to the average cpu of the last tick
			for(var/i in 1 to CPU_SIZE)
				tick_info.cpu_values[i] = world.cpu
			return TRUE
		if("clamp_queue") // last resort for testing, sets queue to the average cpu of the last tick
			for(var/i in 1 to CPU_SIZE)
				tick_info.cpu_values[i] = clamp(tick_info.cpu_values[i], 0, 500)
			return TRUE
		if("toggle_movement")
			GLOB.use_new_glide = !GLOB.use_new_glide
			return TRUE
		if("toggle_compensation")
			GLOB.attempt_corrective_cpu = !GLOB.attempt_corrective_cpu
			return TRUE
		if("catch_negatives")
			GLOB.negative_printed = FALSE
			return TRUE
		if("set_floor")
			var/floor_cpu = tgui_input_number(usr, "How low should we allow the cpu to go?", "Floor CPU", max_value = INFINITY, min_value = 0, default = 0) || 0
			GLOB.floor_cpu = floor_cpu
			return TRUE
		if("set_sustain_cpu")
			var/sustain_cpu = tgui_input_number(usr, "What should we randomly set our cpu to?", "Sustain CPU", max_value = INFINITY, min_value = 0, default = 0) || 0
			GLOB.sustain_cpu = sustain_cpu
			return TRUE
		if("set_sustain_chance")
			var/sustain_cpu_chance = tgui_input_number(usr, "What % of the time should we floor at Sustain CPU", "Sustain CPU %", max_value = 100, min_value = 0, default = 0) || 0
			GLOB.sustain_cpu_chance = sustain_cpu_chance
			return TRUE
		if("set_spike")
			var/spike_cpu = tgui_input_number(usr, "How high should we spike cpu usage", "Spike CPU", max_value = INFINITY, min_value = 0, default = 0) || 0
			GLOB.spike_cpu = spike_cpu
			return TRUE

/world/proc/stash_cpu_values()
	unroll_cpu_value()
	if(fexists(PATH_TO_CPU_STORE))
		fdel(PATH_TO_CPU_STORE)
	var/list/data = list()
	var/datum/tick_holder/tick_info = ____tick_info
	data["average"] = tick_info.avg_cpu_values
	data["raw"] = tick_info.cpu_values
	data["index"] = tick_info.cpu_index
	data["read"] = FALSE
	text2file(json_encode(data), PATH_TO_CPU_STORE)

GLOBAL_REAL_VAR(hell_called)
/world/proc/pull_cpu_values()
	if(isnull(hell_called))
		hell_called = world.time
	var/datum/tick_holder/tick_info = ____tick_info
	if(tick_info.load_var_read == -1000)
		tick_info.load_var_read = world.time
	if(tick_info.last_cpu_update != -1)
		return
	if(tick_info.load_last_cpu == -1000)
		tick_info.load_last_cpu = world.time
	if(!fexists(PATH_TO_CPU_STORE))
		return
	if(tick_info.load_fexists == -1000)
		tick_info.load_fexists = world.time
	var/cpu_file = file(PATH_TO_CPU_STORE)
	if(tick_info.load_file == -1000)
		tick_info.load_file = world.time
	if(!cpu_file)
		return
	var/text_data = file2text(cpu_file)
	if(tick_info.load_2text == -1000)
		tick_info.load_2text = world.time
	if(!text_data)
		return
	tick_info.loaded_json = text_data
	var/list/data = json_decode(text_data)
	if(tick_info.load_decode == -1000)
		tick_info.load_decode = world.time
	if(data["read"])
		return
	if(tick_info.load_data == -1000)
		tick_info.load_data = world.time
	if(!isnull(data["average"]))
		tick_info.avg_cpu_values = data["average"]
	if(!isnull(data["raw"]))
		tick_info.cpu_values = data["raw"]
	if(!isnull(data["index"]))
		tick_info.cpu_index = data["index"]
	data["read"] = TRUE
	if(tick_info.load_end == -1000)
		tick_info.load_end = world.time
	fdel(PATH_TO_CPU_STORE)
	text2file(json_encode(data), PATH_TO_CPU_STORE)


	// Alright we have almost all the cpu values we're missing, except ONE.
	// So we're gonna work out what's missing, and correct for it.
	/*
	var/list/cpu_values = GLOB.cpu_values
	var/list/avg_cpu_values = GLOB.avg_cpu_values
	var/cpu_index = GLOB.cpu_index
	var/avg_cpu = world.cpu

	var/lost_value = cpu_values[WRAP(cpu_index - WINDOW_SIZE, 1, CPU_SIZE + 1)]
	var/last_avg_cpu = avg_cpu_values[WRAP(cpu_index - 1, 1, CPU_SIZE + 1)]
	var/real_cpu = avg_cpu * WINDOW_SIZE - last_avg_cpu * WINDOW_SIZE + lost_value

	var/calculated_avg = real_cpu
	for(var/i in 1 to WINDOW_SIZE - 1)
		calculated_avg += cpu_values[WRAP(cpu_index - i, 1, CPU_SIZE + 1)]
	var/missing_value = world.cpu * WINDOW_SIZE - calculated_avg

	// Alright now we gotta slide it in
	// We
	cpu_values[cpu_index] = real_cpu
	avg_cpu_values[cpu_index] = avg_cpu
	GLOB.cpu_index = WRAP(cpu_index + 1, 1, CPU_SIZE + 1)
*/

/// Holds and tracks information about our current tick
/// Global datum, for real, I am so sorry
/datum/tick_holder
	var/list/cpu_values = new /list(CPU_SIZE)
	var/list/avg_cpu_values = new /list(CPU_SIZE)
	var/list/tick_cpu_usage = new /list(CPU_SIZE)
	var/list/map_cpu_usage = new /list(CPU_SIZE)
	var/list/verb_cost = new /list(CPU_SIZE)
	var/list/cpu_error = new /list(CPU_SIZE)
	var/cpu_index = 1
	var/last_cpu_update = -1
	var/start = -1000
	var/end = -1000
	var/loaded_negative
	var/hell_called = -1000
	var/load_var_read = -1000
	var/load_last_cpu = -1000
	var/load_fexists = -1000
	var/load_file = -1000
	var/load_2text = -1000
	var/load_decode = -1000
	var/load_data = -1000
	var/load_end = -1000
	var/in_step = -1000
	var/calling_cpu = -1000
	var/start_calc = -1000
	var/past_calc = -1000
	var/past_log = -1000
	var/past_log2 = -1000
	var/past_time = -1000
	var/past_cpu = -1000
	var/past_map_cpu = -1000
	var/past_text = -1000
	var/past_map = -1000
	var/loaded_json
	var/log_counter = 0
	var/list/logged = new /list(20)
	var/list/logged_tick = new /list(20)
	var/list/logged_map = new /list(20)
	var/list/pain = list()
	var/logged_tick_late = -1

// Not initialized, because we have to do that manually
// That's how fucked we are
GLOBAL_REAL(____tick_info, /datum/tick_holder)
GLOBAL_DATUM_INIT(tick_info, /datum/tick_holder, ____tick_info)

GLOBAL_VAR_INIT(negative_printed, FALSE)
GLOBAL_VAR_INIT(start_time, 0)
/// Inserts our current world.cpu value into our rolling lists
/// Its job is to pull the actual usage last tick instead of the moving average
/world/proc/unroll_cpu_value()
	var/static/start = -1000
	if(start == -1000)
		start = world.time
	if(GLOB)
		GLOB.start_time = start
	var/static/loaded
	if(!____tick_info)
		____tick_info = new()
		loaded = TRUE
	____tick_info.in_step = loaded

	var/datum/tick_holder/tick_info = ____tick_info
	tick_info.hell_called = hell_called
	if(tick_info.start == -1000)
		tick_info.start = world.time
	if(tick_info.last_cpu_update == world.time)
		return
	// If dreamdeamon did not cleanly reset cpu values carry over, so we need to carry them too
	// If the "last" tick at the start is not 0 then something is hanging over
	var/static/calling_cpu = -1000
	if(calling_cpu == -1000)
		pull_cpu_values()
		calling_cpu = world.time
	tick_info.calling_cpu = calling_cpu
	tick_info.last_cpu_update = world.time
	// cache for sonic speed
	var/list/cpu_values = tick_info.cpu_values
	var/list/avg_cpu_values = tick_info.avg_cpu_values
	var/cpu_index = tick_info.cpu_index
	var/avg_cpu = world.cpu
	// We need to hook into the INSTANT we start our moving average so we can reconstruct gained/lost cpu values
	// Defaults to null or 0 so the wrap here is safe for the first 16 entries
	var/lost_value = cpu_values[WRAP(cpu_index - WINDOW_SIZE, 1, CPU_SIZE + 1)]
	if(tick_info.start_calc == -1000)
		tick_info.start_calc = world.time
	// ok so world.cpu is a 16 entry wide moving average of the actual cpu value
	// because fuck you
	// I want the ACTUAL unrolle value, so I need to deaverage it. this is possible because we have access to ALL values and also math
	// yes byond does average against a constant window size, it doesn't account for a lack of values initially it just sorta assumes they exist.
	// ♪ it ain't me, it ain't me ♪

	// Second tick example
	// avg = (A + B) / 4
	// old_avg = (A) / 4
	// (avg * 4 - old_avg * 4) roughly sans floating point BS = B
	// Fifth tick example
	// avg = (B + C + D + E) / 4
	// old_avg = (A + B + C + D) / 4
	// (avg * 4 - old_avg * 4) roughly = E - A
	// so after we start losing numbers we need to add the one we're losing
	// We're trying to do this with as few ops as possible to avoid noise
	// soooo
	// E = (avg * 4 - old_avg * 4) + A

	var/last_avg_cpu = avg_cpu_values[WRAP(cpu_index - 1, 1, CPU_SIZE + 1)]
	var/real_cpu = avg_cpu * WINDOW_SIZE - last_avg_cpu * WINDOW_SIZE + lost_value

	var/calculated_avg = real_cpu
	for(var/i in 1 to WINDOW_SIZE - 1)
		calculated_avg += cpu_values[WRAP(cpu_index - i, 1, CPU_SIZE + 1)]
	var/inbuilt_error = world.cpu * WINDOW_SIZE - calculated_avg
	// (95.7994 * 16) - 1536.35 == -3.3
	// (a+b+c+d...) / 16 * 16 - (a+b+c+d...) == -g
	var/accounted_cpu = real_cpu + inbuilt_error
	var/tick_and_map = tick_info.tick_cpu_usage[cpu_index] + world.map_cpu
	if(tick_info.past_calc == -1000)
		tick_info.past_calc = world.time

	// due to I think? compounded floating point error either on our side or internal to byond we somtimes get way too large/small cpu values
	// I can't correct in place because I need the full history of averages to add back lost values
	// our cpu value for last tick cannot be lower then the cost of sleeping procs + map cpu, so we'll clamp to that
	// my hope is this will keep error within a reasonable bound as storing a lower then expected number would cause a higher then expected number as a side effect

	if((real_cpu < 0 || accounted_cpu < 0) && GLOB && !GLOB.negative_printed)
		GLOB.negative_printed = TRUE
		log_runtime("Negative real cpu value extracted\n\
			AVG [avg_cpu]; LAST AVG [last_avg_cpu]; LOST VAL [lost_value]; NEW VAL [real_cpu] CALC AVG [calculated_avg]; ERROR [inbuilt_error]; ACCOUNTED [accounted_cpu];\n\
			INDEX [cpu_index]; OLD CPU LIST [json_encode(cpu_values)]")

	if(tick_info.past_log == -1000)
		tick_info.past_log = world.time

	tick_info.log_counter += 1
	var/log_counter = tick_info.log_counter
	if(log_counter < 20)
		var/test = "[world.time]"
		if(tick_info.past_time == -1000)
			tick_info.past_time = world.time
		test = "[world.cpu]"
		if(tick_info.past_cpu == -1000)
			tick_info.past_cpu = world.time
		test = "[world.map_cpu]"
		if(tick_info.past_map_cpu == -1000)
			tick_info.past_map_cpu = world.time
		tick_info.logged[log_counter] = "world.time [world.time]; world.cpu [world.cpu]; world.map_cpu [world.map_cpu]; \n \
			AVG [avg_cpu]; LAST AVG [last_avg_cpu]; LOST VAL [lost_value]; NEW VAL [real_cpu] CALC AVG [calculated_avg]; ERROR [inbuilt_error]; ACCOUNTED [accounted_cpu];\n\
			INDEX [cpu_index]; OLD CPU LIST [json_encode(cpu_values)]"
		if(tick_info.past_text == -1000)
			tick_info.past_text = world.time
		tick_info.logged_map[log_counter] = world.map_cpu
		if(tick_info.past_map == -1000)
			tick_info.past_map = world.time

	if(tick_info.past_log2 == -1000)
		tick_info.past_log2 = world.time

	cpu_values[cpu_index] = real_cpu
	avg_cpu_values[cpu_index] = avg_cpu
	tick_info.map_cpu_usage[cpu_index] = world.map_cpu
	tick_info.verb_cost[cpu_index] = max(accounted_cpu - tick_and_map, 0)
	tick_info.cpu_error[cpu_index] = inbuilt_error
	tick_info.cpu_index = WRAP(cpu_index + 1, 1, CPU_SIZE + 1)
	if(GLOB)
		GLOB.cpu_tracker.update_display()
	if(tick_info.end == -1000)
		tick_info.end = world.time
	// make an animated display of cpu usage to get a better idea of how much we leave on the table
	if(log_counter < 20)
		tick_info.logged_tick[log_counter] = TICK_USAGE

/proc/update_glide_size()
	world.unroll_cpu_value()
	var/datum/tick_holder/tick_info = ____tick_info
	var/list/cpu_values = tick_info.cpu_values
	var/sum = 0
	var/non_zero = 0
	for(var/value in cpu_values)
		sum += max(value, 100)
		if(value != 0)
			non_zero += 1

	var/first_average = non_zero ? sum / non_zero : 1
	var/trimmed_sum = 0
	var/used = 0
	for(var/value in cpu_values)
		if(!value)
			continue
		// If we deviate more then 30% above the average (since we care about filtering spikes), skip us over
		if(1 - (max(value, 100) / first_average) <= 0.3)
			trimmed_sum += max(value, 100)
			used += 1

	var/final_average = trimmed_sum ? trimmed_sum / used : first_average
	GLOB.glide_size_multiplier = min(100 / final_average, 1)

#undef FORMAT_CPU
#undef WINDOW_SIZE
#undef CPU_SIZE

/// Initializes TGS and loads the returned revising info into GLOB.revdata
/world/proc/InitTgs()
	TgsNew(new /datum/tgs_event_handler/impl, TGS_SECURITY_TRUSTED)
	GLOB.revdata.load_tgs_info()

/// Runs after config is loaded but before Master is initialized
/world/proc/ConfigLoaded()
	// Everything in here is prioritized in a very specific way.
	// If you need to add to it, ask yourself hard if what your adding is in the right spot
	// (i.e. basically nothing should be added before load_admins() in here)

	// Try to set round ID
	SSdbcore.InitializeRound()

	SetupLogs()

	load_admins()

	load_poll_data()

	LoadVerbs(/datum/verbs/menu)

	if(fexists(RESTART_COUNTER_PATH))
		GLOB.restart_counter = text2num(trim(file2text(RESTART_COUNTER_PATH)))
		fdel(RESTART_COUNTER_PATH)

/// Runs after the call to Master.Initialize, but before the delay kicks in. Used to turn the world execution into some single function then exit
/world/proc/RunUnattendedFunctions()
	#ifdef UNIT_TESTS
	HandleTestRun()
	#endif

	#ifdef AUTOWIKI
	setup_autowiki()
	#endif

/world/proc/HandleTestRun()
	//trigger things to run the whole process
	Master.sleep_offline_after_initializations = FALSE
	SSticker.start_immediately = TRUE
	CONFIG_SET(number/round_end_countdown, 0)
	var/datum/callback/cb
#ifdef UNIT_TESTS
	cb = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(RunUnitTests))
#else
	cb = VARSET_CALLBACK(SSticker, force_ending, ADMIN_FORCE_END_ROUND)
#endif
	SSticker.OnRoundstart(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(_addtimer), cb, 10 SECONDS))

/// Returns a list of data about the world state, don't clutter
/world/proc/get_world_state_for_logging()
	var/data = list()
	data["tick_usage"] = world.tick_usage
	data["tick_lag"] = world.tick_lag
	data["time"] = world.time
	data["timestamp"] = rustg_unix_timestamp()
	return data

/world/proc/SetupLogs()
	var/override_dir = params[OVERRIDE_LOG_DIRECTORY_PARAMETER]
	if(!override_dir)
		var/realtime = world.realtime
		var/texttime = time2text(realtime, "YYYY/MM/DD")
		GLOB.log_directory = "data/logs/[texttime]/round-"
		GLOB.picture_logging_prefix = "L_[time2text(realtime, "YYYYMMDD")]_"
		GLOB.picture_log_directory = "data/picture_logs/[texttime]/round-"
		if(GLOB.round_id)
			GLOB.log_directory += "[GLOB.round_id]"
			GLOB.picture_logging_prefix += "R_[GLOB.round_id]_"
			GLOB.picture_log_directory += "[GLOB.round_id]"
		else
			var/timestamp = replacetext(time_stamp(), ":", ".")
			GLOB.log_directory += "[timestamp]"
			GLOB.picture_log_directory += "[timestamp]"
			GLOB.picture_logging_prefix += "T_[timestamp]_"
	else
		GLOB.log_directory = "data/logs/[override_dir]"
		GLOB.picture_logging_prefix = "O_[override_dir]_"
		GLOB.picture_log_directory = "data/picture_logs/[override_dir]"

	logger.init_logging()

	if(GLOB.tracy_log)
		rustg_file_write("[GLOB.tracy_log]", "[GLOB.log_directory]/tracy.loc")

	var/latest_changelog = file("[global.config.directory]/../html/changelogs/archive/" + time2text(world.timeofday, "YYYY-MM") + ".yml")
	GLOB.changelog_hash = fexists(latest_changelog) ? md5(latest_changelog) : 0 //for telling if the changelog has changed recently

	if(GLOB.round_id)
		log_game("Round ID: [GLOB.round_id]")

	// This was printed early in startup to the world log and config_error.log,
	// but those are both private, so let's put the commit info in the runtime
	// log which is ultimately public.
	log_runtime(GLOB.revdata.get_log_message())

#ifndef USE_CUSTOM_ERROR_HANDLER
	world.log = file("[GLOB.log_directory]/dd.log")
#else
	if (TgsAvailable()) // why
		world.log = file("[GLOB.log_directory]/dd.log") //not all runtimes trigger world/Error, so this is the only way to ensure we can see all of them.
#endif

/world/Topic(T, addr, master, key)
	TGS_TOPIC //redirect to server tools if necessary

	var/static/list/topic_handlers = TopicHandlers()

	var/list/input = params2list(T)
	var/datum/world_topic/handler
	for(var/I in topic_handlers)
		if(I in input)
			handler = topic_handlers[I]
			break

	if((!handler || initial(handler.log)) && config && CONFIG_GET(flag/log_world_topic))
		log_topic("\"[T]\", from:[addr], master:[master], key:[key]")

	if(!handler)
		return

	handler = new handler()
	return handler.TryRun(input)

/world/proc/AnnouncePR(announcement, list/payload)
	var/static/list/PRcounts = list() //PR id -> number of times announced this round
	var/id = "[payload["pull_request"]["id"]]"
	if(!PRcounts[id])
		PRcounts[id] = 1
	else
		++PRcounts[id]
		if(PRcounts[id] > CONFIG_GET(number/pr_announcements_per_round))
			return

	var/final_composed = span_announce("PR: [announcement]")
	for(var/client/C in GLOB.clients)
		C.AnnouncePR(final_composed)

/world/proc/FinishTestRun()
	set waitfor = FALSE
	var/list/fail_reasons
	if(GLOB)
		if(GLOB.total_runtimes != 0)
			fail_reasons = list("Total runtimes: [GLOB.total_runtimes]")
#ifdef UNIT_TESTS
		if(GLOB.failed_any_test)
			LAZYADD(fail_reasons, "Unit Tests failed!")
#endif
		if(!GLOB.log_directory)
			LAZYADD(fail_reasons, "Missing GLOB.log_directory!")
	else
		fail_reasons = list("Missing GLOB!")
	if(!fail_reasons)
		text2file("Success!", "[GLOB.log_directory]/clean_run.lk")
	else
		log_world("Test run failed!\n[fail_reasons.Join("\n")]")
	sleep(0) //yes, 0, this'll let Reboot finish and prevent byond memes
	qdel(src) //shut it down

/world/Reboot(reason = 0, fast_track = FALSE)
	if (reason || fast_track) //special reboot, do none of the normal stuff
		if (usr)
			log_admin("[key_name(usr)] Has requested an immediate world restart via client side debugging tools")
			message_admins("[key_name_admin(usr)] Has requested an immediate world restart via client side debugging tools")
		to_chat(world, span_boldannounce("Rebooting World immediately due to host request."))
	else
		to_chat(world, span_boldannounce("Rebooting world..."))
		Master.Shutdown() //run SS shutdowns

	#ifdef UNIT_TESTS
	FinishTestRun()
	return
	#else
	if(TgsAvailable())
		var/do_hard_reboot
		// check the hard reboot counter
		var/ruhr = CONFIG_GET(number/rounds_until_hard_restart)
		switch(ruhr)
			if(-1)
				do_hard_reboot = FALSE
			if(0)
				do_hard_reboot = TRUE
			else
				if(GLOB.restart_counter >= ruhr)
					do_hard_reboot = TRUE
				else
					text2file("[++GLOB.restart_counter]", RESTART_COUNTER_PATH)
					do_hard_reboot = FALSE

		if(do_hard_reboot)
			log_world("World hard rebooted at [time_stamp()]")
			world.stash_cpu_values()
			shutdown_logging() // See comment below.
			shutdown_byond_tracy()
			auxcleanup()
			TgsEndProcess()
			return ..()

	log_world("World rebooted at [time_stamp()]")

	world.stash_cpu_values()
	shutdown_logging() // Past this point, no logging procs can be used, at risk of data loss.
	shutdown_byond_tracy()
	auxcleanup()

	TgsReboot() // TGS can decide to kill us right here, so it's important to do it last

	..()
	#endif

/world/proc/auxcleanup()
	var/debug_server = world.GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (debug_server)
		call_ext(debug_server, "auxtools_shutdown")()

/world/Del()
	shutdown_byond_tracy()
	auxcleanup()
	. = ..()

/world/proc/update_status()

	var/list/features = list()

	if(LAZYACCESS(SSlag_switch.measures, DISABLE_NON_OBSJOBS))
		features += "closed"

	var/new_status = ""
	var/hostedby
	if(config)
		var/server_name = CONFIG_GET(string/servername)
		if (server_name)
			new_status += "<b>[server_name]</b> "
		if(CONFIG_GET(flag/allow_respawn))
			features += "respawn" // show "respawn" regardless of "respawn as char" or "free respawn"
		if(!CONFIG_GET(flag/allow_ai))
			features += "AI disabled"
		hostedby = CONFIG_GET(string/hostedby)

	if (CONFIG_GET(flag/station_name_in_hub_entry))
		new_status += " &#8212; <b>[station_name()]</b>"

	var/players = GLOB.clients.len

	game_state = (CONFIG_GET(number/extreme_popcap) && players >= CONFIG_GET(number/extreme_popcap)) //tells the hub if we are full

	if (!host && hostedby)
		features += "hosted by <b>[hostedby]</b>"

	if(length(features))
		new_status += ": [jointext(features, ", ")]"

	if(!SSticker || SSticker?.current_state == GAME_STATE_STARTUP)
		new_status += "<br><b>STARTING</b>"
	else if(SSticker)
		if(SSticker.current_state == GAME_STATE_PREGAME && SSticker.GetTimeLeft() > 0)
			new_status += "<br>Starting: <b>[round((SSticker.GetTimeLeft())/10)]</b>"
		else if(SSticker.current_state == GAME_STATE_SETTING_UP)
			new_status += "<br>Starting: <b>Now</b>"
		else if(SSticker.IsRoundInProgress())
			new_status += "<br>Time: <b>[time2text(STATION_TIME_PASSED(), "hh:mm", 0)]</b>"
			if(SSshuttle?.emergency && SSshuttle?.emergency?.mode != (SHUTTLE_IDLE || SHUTTLE_ENDGAME))
				new_status += " | Shuttle: <b>[SSshuttle.emergency.getModeStr()] [SSshuttle.emergency.getTimerStr()]</b>"
		else if(SSticker.current_state == GAME_STATE_FINISHED)
			new_status += "<br><b>RESTARTING</b>"
	if(SSmapping.current_map)
		new_status += "<br>Map: <b>[SSmapping.current_map.map_path == CUSTOM_MAP_PATH ? "Uncharted Territory" : SSmapping.current_map.map_name]</b>"
	if(SSmap_vote.next_map_config)
		new_status += "[SSmapping.current_map ? " | " : "<br>"]Next: <b>[SSmap_vote.next_map_config.map_path == CUSTOM_MAP_PATH ? "Uncharted Territory" : SSmap_vote.next_map_config.map_name]</b>"

	status = new_status

/world/proc/update_hub_visibility(new_visibility)
	if(new_visibility == GLOB.hub_visibility)
		return
	GLOB.hub_visibility = new_visibility
	if(GLOB.hub_visibility)
		hub_password = "kMZy3U5jJHSiBQjr"
	else
		hub_password = "SORRYNOPASSWORD"

/**
 * Handles increasing the world's maxx var and initializing the new turfs and assigning them to the global area.
 * If map_load_z_cutoff is passed in, it will only load turfs up to that z level, inclusive.
 * This is because maploading will handle the turfs it loads itself.
 */
/world/proc/increase_max_x(new_maxx, map_load_z_cutoff = maxz)
	if(new_maxx <= maxx)
		return
	var/old_max = world.maxx
	maxx = new_maxx
	if(!map_load_z_cutoff)
		return
	var/area/global_area = GLOB.areas_by_type[world.area] // We're guaranteed to be touching the global area, so we'll just do this
	LISTASSERTLEN(global_area.turfs_by_zlevel, map_load_z_cutoff, list())
	for (var/zlevel in 1 to map_load_z_cutoff)
		var/list/to_add = block(
			locate(old_max + 1, 1, zlevel),
			locate(maxx, maxy, zlevel))

		global_area.turfs_by_zlevel[zlevel] += to_add

/world/proc/increase_max_y(new_maxy, map_load_z_cutoff = maxz)
	if(new_maxy <= maxy)
		return
	var/old_maxy = maxy
	maxy = new_maxy
	if(!map_load_z_cutoff)
		return
	var/area/global_area = GLOB.areas_by_type[world.area] // We're guaranteed to be touching the global area, so we'll just do this
	LISTASSERTLEN(global_area.turfs_by_zlevel, map_load_z_cutoff, list())
	for (var/zlevel in 1 to map_load_z_cutoff)
		var/list/to_add = block(
			locate(1, old_maxy + 1, 1),
			locate(maxx, maxy, map_load_z_cutoff))
		global_area.turfs_by_zlevel[zlevel] += to_add

/world/proc/incrementMaxZ()
	maxz++
	SSmobs.MaxZChanged()
	SSai_controllers.on_max_z_changed()

/world/proc/change_fps(new_value = 20)
	if(new_value <= 0)
		CRASH("change_fps() called with [new_value] new_value.")
	if(fps == new_value)
		return //No change required.

	fps = new_value
	on_tickrate_change()


/world/proc/change_tick_lag(new_value = 0.5)
	if(new_value <= 0)
		CRASH("change_tick_lag() called with [new_value] new_value.")
	if(tick_lag == new_value)
		return //No change required.

	tick_lag = new_value
	on_tickrate_change()


/world/proc/on_tickrate_change()
	SStimer?.reset_buckets()
	DREAMLUAU_SET_EXECUTION_LIMIT_MILLIS(tick_lag * 100)

/world/proc/init_byond_tracy()
	if(!fexists(TRACY_DLL_PATH))
		SEND_TEXT(world.log, "Error initializing byond-tracy: [TRACY_DLL_PATH] not found!")
		CRASH("Error initializing byond-tracy: [TRACY_DLL_PATH] not found!")

	var/init_result = call_ext(TRACY_DLL_PATH, "init")("block")
	if(length(init_result) != 0 && init_result[1] == ".") // if first character is ., then it returned the output filename
		SEND_TEXT(world.log, "byond-tracy initialized (logfile: [init_result])")
		GLOB.tracy_initialized = TRUE
		return GLOB.tracy_log = init_result
	else if(init_result == "already initialized") // not gonna question it.
		GLOB.tracy_initialized = TRUE
		SEND_TEXT(world.log, "byond-tracy already initialized ([GLOB.tracy_log ? "logfile: [GLOB.tracy_log]" : "no logfile"])")
	else if(init_result != "0")
		GLOB.tracy_init_error = init_result
		SEND_TEXT(world.log, "Error initializing byond-tracy: [init_result]")
		CRASH("Error initializing byond-tracy: [init_result]")
	else
		GLOB.tracy_initialized = TRUE
		SEND_TEXT(world.log, "byond-tracy initialized (no logfile)")

/world/proc/shutdown_byond_tracy()
	if(GLOB.tracy_initialized)
		SEND_TEXT(world.log, "Shutting down byond-tracy")
		GLOB.tracy_initialized = FALSE
		call_ext(TRACY_DLL_PATH, "destroy")()

/world/proc/init_debugger()
	var/dll = GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (dll)
		call_ext(dll, "auxtools_init")()
		enable_debugging()

/world/Profile(command, type, format)
	if((command & PROFILE_STOP) || !global.config?.loaded || !CONFIG_GET(flag/forbid_all_profiling))
		. = ..()

#undef NO_INIT_PARAMETER
#undef OVERRIDE_LOG_DIRECTORY_PARAMETER
#undef USE_TRACY_PARAMETER
#undef RESTART_COUNTER_PATH
