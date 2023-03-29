/datum/round_event_control/carp_migration
	name = "Carp Migration"
	typepath = /datum/round_event/carp_migration
	weight = 10
	min_players = 30
	earliest_start = 45 MINUTES
	max_occurrences = 2
	category = EVENT_CATEGORY_ENTITIES
	description = "Summons a school of space carp."

/datum/round_event_control/carp_migration/New()
	. = ..()
	if(!HAS_TRAIT(SSstation, STATION_TRAIT_CARP_INFESTATION))
		return
	weight *= 3
	max_occurrences *= 2
	earliest_start *= 0.5

/datum/round_event/carp_migration
	announce_when = 3
	start_when = 50
	/// Set to true when we announce something to ghosts, to prevent duplicate announcements
	var/hasAnnounced = FALSE
	/// Most common mob type to spawn, must be a child of /mob/living/basic/carp
	var/carp_type = /mob/living/basic/carp
	/// Rarer mob type to spawn, must also be a child of /mob/living/basic/carp. If one of these is created, it will take priority to show ghosts.
	var/boss_type = /mob/living/basic/carp/mega
	/// What to describe detecting near the station
	var/fluff_signal = "Unknown biological entities"

/datum/round_event/carp_migration/setup()
	start_when = rand(40, 60)

/datum/round_event/carp_migration/announce(fake)
	priority_announce("[fluff_signal] have been detected near [station_name()], please stand-by.", "Lifesign Alert")

/datum/round_event/carp_migration/start()
	// Stores the most recent fish we spawn
	var/mob/living/basic/carp/fish
	// Associated lists of z level to a list of points to travel to, so that grouped fish move to the same places
	var/list/z_migration_paths = list()

	for(var/obj/effect/landmark/carpspawn/spawn_point in GLOB.landmarks_list)
		if(prob(95))
			fish = new carp_type(spawn_point.loc)
		else
			fish = new boss_type(spawn_point.loc)
			fishannounce(fish) //Prefer to announce the megacarps over the regular fishies

		var/z_level_key = "[spawn_point.z]"
		if (!z_migration_paths[z_level_key])
			z_migration_paths[z_level_key] = pick_carp_migration_points(z_level_key)
		if (z_migration_paths[z_level_key]) // Still possible we failed to set anything here if we're unlucky
			fish.migrate_to(z_migration_paths[z_level_key])

	fishannounce(fish)

/// Generate two locations for carp to travel to, one in the station and one off in space
/datum/round_event/carp_migration/proc/pick_carp_migration_points(z_level_key)
	var/list/valid_areas = list()
	var/list/station_areas = GLOB.the_station_areas
	for (var/area/potential_area as anything in SSmapping.areas_in_z[z_level_key])
		if (!is_type_in_list(potential_area, station_areas))
			continue
		valid_areas += potential_area

	var/turf/station_turf = get_safe_random_station_turf(valid_areas)
	if (!station_turf)
		return list()
	var/turf/exit_turf = get_edge_target_turf(station_turf, pick(GLOB.alldirs))
	return list(WEAKREF(station_turf), WEAKREF(exit_turf))

/datum/round_event/carp_migration/proc/fishannounce(atom/fish)
	if (!hasAnnounced)
		announce_to_ghosts(fish) //Only anounce the first fish
		hasAnnounced = TRUE
