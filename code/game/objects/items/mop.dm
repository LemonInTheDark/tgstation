/obj/item/mop
	desc = "The world of janitalia wouldn't be complete without a mop."
	name = "mop"
	icon = 'icons/obj/janitor.dmi'
	icon_state = "mop"
	lefthand_file = 'icons/mob/inhands/equipment/custodial_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/custodial_righthand.dmi'
	force = 8
	throwforce = 10
	throw_speed = 3
	throw_range = 7
	w_class = WEIGHT_CLASS_NORMAL
	attack_verb_continuous = list("mops", "bashes", "bludgeons", "whacks")
	attack_verb_simple = list("mop", "bash", "bludgeon", "whack")
	resistance_flags = FLAMMABLE
	var/mopcount = 0
	///Maximum volume of reagents it can hold.
	var/max_reagent_volume = 15
	var/mopspeed = 1.5 SECONDS
	force_string = "robust... against germs"
	var/insertable = TRUE

/obj/item/mop/Initialize(mapload)
	. = ..()
	create_reagents(max_reagent_volume)
	GLOB.janitor_devices += src

/obj/item/mop/Destroy(force)
	GLOB.janitor_devices -= src
	return ..()

/obj/item/mop/proc/clean(turf/A, mob/living/cleaner)
	if(reagents.has_chemical_flag(REAGENT_CLEANS, 1))
		// If there's a cleaner with a mind, let's gain some experience!
		if(cleaner?.mind)
			var/total_experience_gain = 0
			for(var/obj/effect/decal/cleanable/cleanable_decal in A)
				//it is intentional that the mop rounds xp but soap does not, USE THE SACRED TOOL
				total_experience_gain += max(round(cleanable_decal.beauty / CLEAN_SKILL_BEAUTY_ADJUSTMENT, 1), 0)
			cleaner.mind.adjust_experience(/datum/skill/cleaning, total_experience_gain)
		A.wash(CLEAN_SCRUB)

	reagents.expose(A, TOUCH, 10) //Needed for proper floor wetting.
	var/val2remove = 1
	if(cleaner?.mind)
		val2remove = round(cleaner.mind.get_skill_modifier(/datum/skill/cleaning, SKILL_SPEED_MODIFIER),0.1)
	reagents.remove_any(val2remove) //reaction() doesn't use up the reagents


/obj/item/mop/afterattack(atom/A, mob/user, proximity)
	. = ..()
	if(!proximity)
		return

	if(reagents.total_volume < 0.1)
		to_chat(user, span_warning("Your mop is dry!"))
		return

	var/turf/T = get_turf(A)

	if(istype(A, /obj/item/reagent_containers/glass/bucket) || istype(A, /obj/structure/janitorialcart))
		return

	if(T)
		user.visible_message(span_notice("[user] begins to clean \the [T] with [src]."), span_notice("You begin to clean \the [T] with [src]..."))
		var/clean_speedies = 1
		if(user.mind)
			clean_speedies = user.mind.get_skill_modifier(/datum/skill/cleaning, SKILL_SPEED_MODIFIER)
		if(do_after(user, mopspeed*clean_speedies, target = T))
			to_chat(user, span_notice("You finish mopping."))
			clean(T, user)

/obj/item/mop/cyborg/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, CYBORG_ITEM_TRAIT)

/obj/item/mop/advanced
	desc = "The most advanced tool in a custodian's arsenal, complete with a condenser for self-wetting! Just think of all the viscera you will clean up with this!"
	name = "advanced mop"
	max_reagent_volume = 10
	icon_state = "advmop"
	inhand_icon_state = "mop"
	lefthand_file = 'icons/mob/inhands/equipment/custodial_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/custodial_righthand.dmi'
	force = 12
	throwforce = 14
	throw_range = 4
	mopspeed = 0.8 SECONDS
	var/refill_enabled = TRUE //Self-refill toggle for when a janitor decides to mop with something other than water.
	/// Amount of reagent to refill per second
	var/refill_rate = 0.5
	var/refill_reagent = /datum/reagent/water //Determins what reagent to use for refilling, just in case someone wanted to make a HOLY MOP OF PURGING

/obj/item/mop/advanced/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/mop/advanced/attack_self(mob/user)
	refill_enabled = !refill_enabled
	if(refill_enabled)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj,src)
	to_chat(user, span_notice("You set the condenser switch to the '[refill_enabled ? "ON" : "OFF"]' position."))
	playsound(user, 'sound/machines/click.ogg', 30, TRUE)

/obj/item/mop/advanced/process(delta_time)
	var/amadd = min(max_reagent_volume - reagents.total_volume, refill_rate * delta_time)
	if(amadd > 0)
		reagents.add_reagent(refill_reagent, amadd)

/obj/item/mop/advanced/examine(mob/user)
	. = ..()
	. += span_notice("The condenser switch is set to <b>[refill_enabled ? "ON" : "OFF"]</b>.")

/obj/item/mop/advanced/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/mop/advanced/cyborg
	insertable = FALSE

/proc/lmao_lol(text)
	var/rust = rustg_url_encode(text)
	var/stainless = url_encode(text)
	//if(rust != stainless)
		//log_world("Encoding [text] lead to two different outputs between rustg and url_encode:\n([rust])\nand ([stainless]) [istext(rust)] [istext(stainless)]")

/proc/encoding_master(text)
	return lmao_lol(json_encode(text))

/atom/proc/check_encode()
	set waitfor = FALSE
	check_encode_base()
	check_encode_no_round()
	check_encode_no_round_time()
	check_encode_no_server()
	check_encode_default_data()
	check_encode_no_station_time()
	check_encode_no_td()
	check_encode_nothing()
	check_encode_paired()
	check_encode_rand()
	check_encode_no_map()
	check_encode_no_null()
	check_encode_rand_len()
	check_encode_long()

/* Obsoleted functions
check_encode_no_td
check_encode_no_station_time
check_encode_no_round_time
check_encode_no_round
check_encode_base
*/

/atom/proc/check_encode_base()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Round Time: [ROUND_TIME]",
		"Station Time: [station_time_timestamp()]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_paired()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_rand()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list()
		for(var/i in 1 to 7)
			global_data += "[rand(1,1000)]"

		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_rand_len()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list()
		for(var/i in 1 to rand(1, 5) * 100)
			global_data += "haha fuck you kuler hdasudawdhs awjdsajsd lu vfwadaskwda dioasdj"

		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_long()
	set waitfor = FALSE
	var/iterations = 0

	var/list/global_data = list()
	for(var/i in 1 to 8000)
		global_data += "haha fuck you kuler hdasudawdhs awjdsajsd lu vfwadaskwda dioasdj [rand(1,1000)]"

	while(TRUE)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_map()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		null,
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Round Time: [ROUND_TIME]",
		"Station Time: [station_time_timestamp()]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_null()
	set waitfor = FALSE

	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Round Time: [ROUND_TIME]",
		"Station Time: [station_time_timestamp()]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_round()
	set waitfor = FALSE

	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Round Time: [ROUND_TIME]",
		"Station Time: [station_time_timestamp()]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_server()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Round Time: [ROUND_TIME]",
		"Station Time: [station_time_timestamp()]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_round_time()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Station Time: [station_time_timestamp()]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_station_time()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Round Time: [ROUND_TIME]",
		"Time Dilation: [round(SStime_track.time_dilation_current,1)] AVG:([round(SStime_track.time_dilation_avg_fast,1)], [round(SStime_track.time_dilation_avg,1)], [round(SStime_track.time_dilation_avg_slow,1)])"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_no_td()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
		"Map: [SSmapping.config?.map_name || "Loading..."]",
		null,
		"Round ID: [GLOB.round_id ? GLOB.round_id : "NULL"]",
		"Server Time: [time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")]",
		"Round Time: [ROUND_TIME]",
		"Station Time: [station_time_timestamp()]",
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_default_data()
	set waitfor = FALSE
	var/iterations = 0

	var/list/data = list(
		"Map: Tramstation",
		null,
		"Round ID: NULL",
		"Server Time: 2022-04-13 22:51:50",
		"Round Time: 23:06:52",
		"Station Time: 12:18:31",
		"Time Dilation: 0% AVG:(0%, 0%, 0%)"
	)

	while(TRUE)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0

/atom/proc/check_encode_nothing()
	set waitfor = FALSE
	var/iterations = 0

	while(TRUE)
		var/list/global_data = list(
			"a",
			"b"
		)
		iterations++
		var/start_usage = world.tick_usage
		var/list/output = encoding_master(global_data)
		var/duration = world.tick_usage - start_usage
		if(duration > 100)
			log_world("a single json_encode() call took [duration] percent of a tick after [iterations] iterations! [__LINE__]")
			return
		if(iterations >= (1<<22))
			log_world("wasnt found with a static list, trying again with a constantly changing list [__LINE__]")
			break
		sleep(world.tick_lag * 4)

	iterations = 0
