/datum/round_event_control/aurora_caelus
	name = "Aurora Caelus"
	typepath = /datum/round_event/aurora_caelus
	max_occurrences = 1
	weight = 1
	earliest_start = 5 MINUTES
	category = EVENT_CATEGORY_FRIENDLY
	description = "A colourful display can be seen through select windows. And the kitchen."

/datum/round_event_control/aurora_caelus/can_spawn_event(players, allow_magic = FALSE)
	if(!CONFIG_GET(flag/starlight) && !(SSmapping.empty_space))
		return FALSE
	return ..()

/datum/round_event/aurora_caelus
	announce_when = 1
	start_when = 9
	end_when = 50
	var/list/aurora_colors = list("#A2FF80", "#A2FF8B", "#A2FF96", "#A2FFA5", "#A2FFB6", "#A2FFC7", "#A2FFDE", "#A2FFEE")
	var/aurora_progress = 0 //this cycles from 1 to 8, slowly changing colors from gentle green to gentle blue

/datum/round_event/aurora_caelus/announce()
	priority_announce("[station_name()]: A harmless cloud of ions is approaching your station, and will exhaust their energy battering the hull. Nanotrasen has approved a short break for all employees to relax and observe this very rare event. During this time, starlight will be bright but gentle, shifting between quiet green and blue colors. Any staff who would like to view these lights for themselves may proceed to the area nearest to them with viewing ports to open space. We hope you enjoy the lights.",
	sound = 'sound/misc/notice2.ogg',
	sender_override = "Nanotrasen Meteorology Division")
	for(var/V in GLOB.player_list)
		var/mob/M = V
		if((M.client.prefs.read_preference(/datum/preference/toggle/sound_midi)) && is_station_level(M.z))
			M.playsound_local(M, 'sound/ambience/aurora_caelus.ogg', 20, FALSE, pressure_affected = FALSE)

/datum/round_event/aurora_caelus/start()
	for(var/turf/open/space/star as anything in GLOB.lit_stars)
		star.set_light(star.light_range * 3, star.light_power * (1/3 * 0.5))

	for(var/area/station/service/kitchen/roasting_zone in GLOB.areas)
		for(var/turf/open/kitchen in roasting_zone.get_contained_turfs())
			kitchen.set_light(1, 0.75)
		if(!prob(1) && !check_holidays(APRIL_FOOLS))
			continue
		var/obj/machinery/oven/roast_ruiner = locate() in roasting_zone
		if(roast_ruiner)
			roast_ruiner.balloon_alert_to_viewers("oh egads!")
			var/turf/ruined_roast = get_turf(roast_ruiner)
			ruined_roast.atmos_spawn_air("plasma=100;TEMP=1000")
			message_admins("Aurora Caelus event caused an oven to ignite at [ADMIN_VERBOSEJMP(ruined_roast)].")
			log_game("Aurora Caelus event caused an oven to ignite at [loc_name(ruined_roast)].")
		for(var/mob/living/carbon/human/seymour as anything in GLOB.human_list)
			if(seymour.mind && istype(seymour.mind.assigned_role, /datum/job/cook))
				seymour.say("My roast is ruined!!!", forced = "ruined roast")
				seymour.emote("scream")

/datum/round_event/aurora_caelus/tick()
	if(activeFor % 5 == 0)
		aurora_progress++
		var/aurora_color = aurora_colors[aurora_progress]
		for(var/turf/open/space/star as anything in GLOB.lit_stars)
			star.set_light(l_color = aurora_color)

		for(var/area/station/service/kitchen/roasting_zone in GLOB.areas)
			for(var/turf/open/kitchen_floor in roasting_zone.get_contained_turfs())
				kitchen_floor.set_light(l_color = aurora_color)

/datum/round_event/aurora_caelus/end()
	fade_stars_to_black()

	for(var/area/station/service/kitchen/roasting_zone in GLOB.areas)
		for(var/turf/open/superturfentent in roasting_zone.get_contained_turfs())
			fade_to_black(superturfentent)
	priority_announce("The aurora caelus event is now ending. Starlight conditions will slowly return to normal. When this has concluded, please return to your workplace and continue work as normal. Have a pleasant shift, [station_name()], and thank you for watching with us.",
	sound = 'sound/misc/notice2.ogg',
	sender_override = "Nanotrasen Meteorology Division")

#warn lemontodo: batch sleeps brother
/datum/round_event/aurora_caelus/proc/fade_to_black(turf/open/space/spess)
	set waitfor = FALSE
	var/new_light = initial(spess.light_range)
	while(spess.light_range > new_light)
		spess.set_light(spess.light_range - 0.2)
		sleep(3 SECONDS)
	spess.set_light(new_light, initial(spess.light_power), initial(spess.light_color))

/datum/round_event/aurora_caelus/proc/fade_stars_to_black()
	set waitfor = FALSE
	var/turf/open/space/starlit_path = /turf/open/space
	var/current_range = SPACE_STARLIGHT_RANGE * 3
	var/target_range = SPACE_STARLIGHT_RANGE
	var/target_power = initial(starlit_path.light_power)
	var/current_power = target_power * (1/3 * 0.5)

	var/distance_to_travel = abs(target_range - current_range)
	var/step_count = CEILING(distance_to_travel / 0.2, 1)

	var/range_step_size = (target_range - current_range) / step_count
	var/power_step_size = (target_power - current_power) / step_count

	var/last_aurora_color = aurora_colors[aurora_progress]
	var/list/starlight_gradient = list(0, last_aurora_color, 1, COLOR_STARLIGHT, "space"=COLORSPACE_HSL)
	#warn this is broken why is htat
	for(var/i in 1 to step_count)
		var/active_color = gradient(starlight_gradient, i / step_count)
		current_range += range_step_size
		current_power += power_step_size

		for(var/turf/open/space/star as anything in GLOB.lit_stars)
			star.set_light(current_range, current_power, active_color)
		sleep(3 SECONDS)

