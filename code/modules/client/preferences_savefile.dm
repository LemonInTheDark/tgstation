//This is the lowest supported version, anything below this is completely obsolete and the entire savefile will be wiped.
#define SAVEFILE_VERSION_MIN 32

//This is the current version, anything below this will attempt to update (if it's not obsolete)
// You do not need to raise this if you are adding new values that have sane defaults.
// Only raise this value when changing the meaning/format/name/layout of an existing value
// where you would want the updater procs below to run
#define SAVEFILE_VERSION_MAX 41

/*
SAVEFILE UPDATING/VERSIONING - 'Simplified', or rather, more coder-friendly ~Carn
	This proc checks if the current directory of the savefile S needs updating
	It is to be used by the load_character and load_preferences procs.
	(S.cd=="/" is preferences, S.cd=="/character[integer]" is a character slot, etc)

	if the current directory's version is below SAVEFILE_VERSION_MIN it will simply wipe everything in that directory
	(if we're at root "/" then it'll just wipe the entire savefile, for instance.)

	if its version is below SAVEFILE_VERSION_MAX but above the minimum, it will load data but later call the
	respective update_preferences() or update_character() proc.
	Those procs allow coders to specify format changes so users do not lose their setups and have to redo them again.

	Failing all that, the standard sanity checks are performed. They simply check the data is suitable, reverting to
	initial() values if necessary.
*/
/datum/preferences/proc/savefile_needs_update(savefile/S)
	var/savefile_version
	READ_FILE(S["version"], savefile_version)

	if(savefile_version < SAVEFILE_VERSION_MIN)
		S.dir.Cut()
		return -2
	if(savefile_version < SAVEFILE_VERSION_MAX)
		return savefile_version
	return -1

//should these procs get fairly long
//just increase SAVEFILE_VERSION_MIN so it's not as far behind
//SAVEFILE_VERSION_MAX and then delete any obsolete if clauses
//from these procs.
//This only really meant to avoid annoying frequent players
//if your savefile is 3 months out of date, then 'tough shit'.

/datum/preferences/proc/update_preferences(current_version, savefile/S)
	if(current_version < 33)
		toggles |= SOUND_ENDOFROUND

	if(current_version < 34)
		auto_fit_viewport = TRUE

	if(current_version < 35) //makes old keybinds compatible with #52040, sets the new default
		var/newkey = FALSE
		for(var/list/key in key_bindings)
			for(var/bind in key)
				if(bind == "quick_equipbelt")
					key -= "quick_equipbelt"
					key |= "quick_equip_belt"

				if(bind == "bag_equip")
					key -= "bag_equip"
					key |= "quick_equip_bag"

				if(bind == "quick_equip_suit_storage")
					newkey = TRUE
		if(!newkey && !key_bindings["ShiftQ"])
			key_bindings["ShiftQ"] = list("quick_equip_suit_storage")

	if(current_version < 36)
		if(key_bindings["ShiftQ"] == "quick_equip_suit_storage")
			key_bindings["ShiftQ"] = list("quick_equip_suit_storage")

	if(current_version < 37)
		if(clientfps == 0)
			clientfps = -1

	if (current_version < 38)
		var/found_block_movement = FALSE

		for (var/list/key in key_bindings)
			for (var/bind in key)
				if (bind == "block_movement")
					found_block_movement = TRUE
					break
			if (found_block_movement)
				break

		if (!found_block_movement)
			LAZYADD(key_bindings["Ctrl"], "block_movement")

	if (current_version < 39)
		LAZYADD(key_bindings["F"], "toggle_combat_mode")
		LAZYADD(key_bindings["4"], "toggle_combat_mode")
	if (current_version < 40)
		LAZYADD(key_bindings["Space"], "hold_throw_mode")

	if (current_version < 41)
		var/new_key_bindings = list()

		// MOTHBLOCKS TODO: Migrate antags, check midround antagonists preference

		for (var/hotkey in key_bindings)
			if (hotkey == "Unbound")
				continue

			for (var/keybind in key_bindings[hotkey])
				if (keybind in new_key_bindings)
					new_key_bindings[keybind] |= hotkey
				else
					new_key_bindings[keybind] = list(hotkey)

		key_bindings = new_key_bindings

/datum/preferences/proc/update_character(current_version, savefile/S)
	return

/// checks through keybindings for outdated unbound keys and updates them
/datum/preferences/proc/check_keybindings()
	if(!parent)
		return
	var/list/binds_by_key = key_bindings || list()
	for (var/kb_name in key_bindings)
		for(var/key in key_bindings[kb_name])
			binds_by_key[key] += list(kb_name)
	var/list/notadded = list()
	for (var/name in GLOB.keybindings_by_name)
		var/datum/keybinding/kb = GLOB.keybindings_by_name[name]
		if(length(key_bindings[kb.name]))
			continue // key is unbound and or bound to something
		var/addedbind = FALSE
		if(hotkeys)
			for(var/hotkeytobind in kb.hotkey_keys)
				if(!length(binds_by_key[hotkeytobind]) || hotkeytobind == "Unbound") //Only bind to the key if nothing else is bound expect for Unbound
					LAZYOR(key_bindings[kb.name], hotkeytobind)
					addedbind = TRUE
		else
			for(var/classickeytobind in kb.classic_keys)
				if(!length(binds_by_key[classickeytobind]) || classickeytobind == "Unbound") //Only bind to the key if nothing else is bound expect for Unbound
					LAZYOR(key_bindings[kb.name], classickeytobind)
					addedbind = TRUE
		if(!addedbind)
			notadded += kb
	save_preferences() //Save the players pref so that new keys that were set to Unbound as default are permanently stored
	if(length(notadded))
		addtimer(CALLBACK(src, .proc/announce_conflict, notadded), 5 SECONDS)

/datum/preferences/proc/announce_conflict(list/notadded)
	to_chat(parent, "<span class='warningplain'><b><u>Keybinding Conflict</u></b></span>\n\
					<span class='warningplain'><b>There are new <a href='?_src_=prefs;preference=tab;tab=3'>keybindings</a> that default to keys you've already bound. The new ones will be unbound.</b></span>")
	for(var/item in notadded)
		var/datum/keybinding/conflicted = item
		to_chat(parent, span_danger("[conflicted.category]: [conflicted.full_name] needs updating"))


/datum/preferences/proc/load_path(ckey,filename="preferences.sav")
	if(!ckey)
		return
	path = "data/player_saves/[ckey[1]]/[ckey]/[filename]"

/datum/preferences/proc/load_preferences()
	if(!path)
		return FALSE
	if(!fexists(path))
		return FALSE

	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/"

	var/needs_update = savefile_needs_update(S)
	if(needs_update == -2) //fatal, can't load any data
		var/bacpath = "[path].updatebac" //todo: if the savefile version is higher then the server, check the backup, and give the player a prompt to load the backup
		if (fexists(bacpath))
			fdel(bacpath) //only keep 1 version of backup
		fcopy(S, bacpath) //byond helpfully lets you use a savefile for the first arg.
		return FALSE

	for (var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if (preference.savefile_identifier != PREFERENCE_PLAYER)
			continue

		value_cache -= preference.type
		preference.apply_to_client(parent, read_preference(preference.type))

	//general preferences
	READ_FILE(S["lastchangelog"], lastchangelog)
	READ_FILE(S["hotkeys"], hotkeys)
	READ_FILE(S["chat_on_map"], chat_on_map)
	READ_FILE(S["max_chat_length"], max_chat_length)
	READ_FILE(S["see_chat_non_mob"] , see_chat_non_mob)

	READ_FILE(S["tgui_fancy"], tgui_fancy)
	READ_FILE(S["tgui_lock"], tgui_lock)
	READ_FILE(S["buttons_locked"], buttons_locked)
	READ_FILE(S["be_special"] , be_special)


	READ_FILE(S["default_slot"], default_slot)
	READ_FILE(S["chat_toggles"], chat_toggles)
	READ_FILE(S["toggles"], toggles)
	READ_FILE(S["ignoring"], ignoring)
	READ_FILE(S["ghost_hud"], ghost_hud)
	READ_FILE(S["inquisitive_ghost"], inquisitive_ghost)
	READ_FILE(S["clientfps"], clientfps)
	READ_FILE(S["parallax"], parallax)
	READ_FILE(S["screentip_pref"], screentip_pref)
	READ_FILE(S["itemoutline_pref"], itemoutline_pref)
	READ_FILE(S["auto_fit_viewport"], auto_fit_viewport)
	READ_FILE(S["widescreenpref"], widescreenpref)
	READ_FILE(S["menuoptions"], menuoptions)
	READ_FILE(S["pda_color"], pda_color)

	// OOC commendations
	READ_FILE(S["hearted_until"], hearted_until)
	if(hearted_until > world.realtime)
		hearted = TRUE
	//favorite outfits
	READ_FILE(S["favorite_outfits"], favorite_outfits)

	var/list/parsed_favs = list()
	for(var/typetext in favorite_outfits)
		var/datum/outfit/path = text2path(typetext)
		if(ispath(path)) //whatever typepath fails this check probably doesn't exist anymore
			parsed_favs += path
	favorite_outfits = uniqueList(parsed_favs)

	// Custom hotkeys
	READ_FILE(S["key_bindings"], key_bindings)
	check_keybindings() // this apparently fails every time and overwrites any unloaded prefs with the default values, so don't load anything after this line or it won't actually save
	key_bindings_by_key = get_key_bindings_by_key(key_bindings)

	//try to fix any outdated data if necessary
	if(needs_update >= 0)
		var/bacpath = "[path].updatebac" //todo: if the savefile version is higher then the server, check the backup, and give the player a prompt to load the backup
		if (fexists(bacpath))
			fdel(bacpath) //only keep 1 version of backup
		fcopy(S, bacpath) //byond helpfully lets you use a savefile for the first arg.
		update_preferences(needs_update, S) //needs_update = savefile_version if we need an update (positive integer)



	//Sanitize
	lastchangelog = sanitize_text(lastchangelog, initial(lastchangelog))
	hotkeys = sanitize_integer(hotkeys, FALSE, TRUE, initial(hotkeys))
	chat_on_map = sanitize_integer(chat_on_map, FALSE, TRUE, initial(chat_on_map))
	max_chat_length = sanitize_integer(max_chat_length, 1, CHAT_MESSAGE_MAX_LENGTH, initial(max_chat_length))
	see_chat_non_mob = sanitize_integer(see_chat_non_mob, FALSE, TRUE, initial(see_chat_non_mob))
	tgui_fancy = sanitize_integer(tgui_fancy, FALSE, TRUE, initial(tgui_fancy))
	tgui_lock = sanitize_integer(tgui_lock, FALSE, TRUE, initial(tgui_lock))
	buttons_locked = sanitize_integer(buttons_locked, FALSE, TRUE, initial(buttons_locked))
	default_slot = sanitize_integer(default_slot, 1, max_save_slots, initial(default_slot))
	toggles = sanitize_integer(toggles, 0, (2**24)-1, initial(toggles))
	clientfps = sanitize_integer(clientfps, -1, 1000, 0)
	parallax = sanitize_integer(parallax, PARALLAX_INSANE, PARALLAX_DISABLE, null)
	screentip_pref	= sanitize_integer(screentip_pref, FALSE, TRUE, initial(screentip_pref))
	itemoutline_pref = sanitize_integer(itemoutline_pref, FALSE, TRUE, initial(itemoutline_pref))
	auto_fit_viewport	= sanitize_integer(auto_fit_viewport, FALSE, TRUE, initial(auto_fit_viewport))
	widescreenpref  = sanitize_integer(widescreenpref, FALSE, TRUE, initial(widescreenpref))
	menuoptions = SANITIZE_LIST(menuoptions)
	be_special = SANITIZE_LIST(be_special)
	pda_color = sanitize_hexcolor(pda_color, 6, 1, initial(pda_color))
	key_bindings = sanitize_keybindings(key_bindings)
	favorite_outfits = SANITIZE_LIST(favorite_outfits)

	if(needs_update >= 0) //save the updated version
		var/old_default_slot = default_slot
		var/old_max_save_slots = max_save_slots

		for (var/slot in S.dir) //but first, update all current character slots.
			if (copytext(slot, 1, 10) != "character")
				continue
			var/slotnum = text2num(copytext(slot, 10))
			if (!slotnum)
				continue
			max_save_slots = max(max_save_slots, slotnum) //so we can still update byond member slots after they lose memeber status
			default_slot = slotnum
			if (load_character())
				save_character()
		default_slot = old_default_slot
		max_save_slots = old_max_save_slots
		save_preferences()

	return TRUE

/datum/preferences/proc/save_preferences()
	if(!path)
		return FALSE
	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/"

	WRITE_FILE(S["version"] , SAVEFILE_VERSION_MAX) //updates (or failing that the sanity checks) will ensure data is not invalid at load. Assume up-to-date

	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if (preference.savefile_identifier != PREFERENCE_PLAYER)
			continue

		write_preference(preference, read_preference(preference_type))

	//general preferences
	WRITE_FILE(S["lastchangelog"], lastchangelog)
	WRITE_FILE(S["hotkeys"], hotkeys)
	WRITE_FILE(S["chat_on_map"], chat_on_map)
	WRITE_FILE(S["max_chat_length"], max_chat_length)
	WRITE_FILE(S["see_chat_non_mob"], see_chat_non_mob)
	WRITE_FILE(S["tgui_fancy"], tgui_fancy)
	WRITE_FILE(S["tgui_lock"], tgui_lock)
	WRITE_FILE(S["buttons_locked"], buttons_locked)
	WRITE_FILE(S["be_special"], be_special)
	WRITE_FILE(S["default_slot"], default_slot)
	WRITE_FILE(S["toggles"], toggles)
	WRITE_FILE(S["chat_toggles"], chat_toggles)
	WRITE_FILE(S["ignoring"], ignoring)
	WRITE_FILE(S["ghost_hud"], ghost_hud)
	WRITE_FILE(S["inquisitive_ghost"], inquisitive_ghost)
	WRITE_FILE(S["clientfps"], clientfps)
	WRITE_FILE(S["parallax"], parallax)
	WRITE_FILE(S["screentip_pref"], screentip_pref)
	WRITE_FILE(S["itemoutline_pref"], itemoutline_pref)
	WRITE_FILE(S["auto_fit_viewport"], auto_fit_viewport)
	WRITE_FILE(S["widescreenpref"], widescreenpref)
	WRITE_FILE(S["menuoptions"], menuoptions)
	WRITE_FILE(S["pda_color"], pda_color)
	// MOTHBLOCKS TODO: FIGURE OUT THE DUPLICATION BUG
	// WRITE_FILE(S["key_bindings"], key_bindings)
	WRITE_FILE(S["hearted_until"], (hearted_until > world.realtime ? hearted_until : null))
	WRITE_FILE(S["favorite_outfits"], favorite_outfits)
	return TRUE

/datum/preferences/proc/load_character(slot)
	if(!path)
		return FALSE
	if(!fexists(path))
		return FALSE
	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/"
	if(!slot)
		slot = default_slot
	slot = sanitize_integer(slot, 1, max_save_slots, initial(default_slot))
	if(slot != default_slot)
		default_slot = slot
		WRITE_FILE(S["default_slot"] , slot)

	S.cd = "/character[slot]"
	var/needs_update = savefile_needs_update(S)
	if(needs_update == -2) //fatal, can't load any data
		return FALSE

	// Read everything into cache
	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if (preference.savefile_identifier != PREFERENCE_CHARACTER)
			continue

		value_cache -= value_cache
		read_preference(preference_type)

	//Character
	READ_FILE(S["body_type"], body_type)
	READ_FILE(S["skin_tone"], skin_tone)
	READ_FILE(S["underwear_color"], underwear_color)
	READ_FILE(S["playtime_reward_cloak"], playtime_reward_cloak)
	READ_FILE(S["phobia"], phobia)
	READ_FILE(S["randomise"],  randomise)
	READ_FILE(S["feature_mcolor"], features["mcolor"])
	READ_FILE(S["feature_ethcolor"], features["ethcolor"])
	READ_FILE(S["feature_lizard_tail"], features["tail_lizard"])
	READ_FILE(S["feature_lizard_snout"], features["snout"])
	READ_FILE(S["feature_lizard_horns"], features["horns"])
	READ_FILE(S["feature_lizard_frills"], features["frills"])
	READ_FILE(S["feature_lizard_spines"], features["spines"])
	READ_FILE(S["feature_lizard_body_markings"], features["body_markings"])
	READ_FILE(S["feature_lizard_legs"], features["legs"])
	READ_FILE(S["persistent_scars"] , persistent_scars)
	if(!CONFIG_GET(flag/join_with_mutant_humans))
		features["tail_human"] = "none"
		features["ears"] = "none"
	else
		READ_FILE(S["feature_human_tail"], features["tail_human"])
		READ_FILE(S["feature_human_ears"], features["ears"])

	//Custom names
	for(var/custom_name_id in GLOB.preferences_custom_names)
		var/savefile_slot_name = custom_name_id + "_name" //TODO remove this
		READ_FILE(S[savefile_slot_name], custom_names[custom_name_id])

	READ_FILE(S["preferred_ai_core_display"], preferred_ai_core_display)
	READ_FILE(S["prefered_security_department"], prefered_security_department)

	// This is the version when the random security department was removed.
	// When the minimum is higher than that version, it's impossible for someone to have the "Random" department.
	#if SAVEFILE_VERSION_MIN > 40
	#warn The prefered_security_department check in preferences_savefile.dm is no longer necessary.
	#endif

	if (!(prefered_security_department in GLOB.security_depts_prefs))
		prefered_security_department = SEC_DEPT_NONE

	//Jobs
	READ_FILE(S["joblessrole"], joblessrole)
	//Load prefs
	READ_FILE(S["job_preferences"], job_preferences)

	//Quirks
	READ_FILE(S["all_quirks"], all_quirks)

	//try to fix any outdated data if necessary
	//preference updating will handle saving the updated data for us.
	if(needs_update >= 0)
		update_character(needs_update, S) //needs_update == savefile_version if we need an update (positive integer)

	//Sanitize

	// MOTHBLOCKS TODO: Body type
	// body_type = sanitize_gender(body_type, FALSE, FALSE, gender)

	for(var/custom_name_id in GLOB.preferences_custom_names)
		var/namedata = GLOB.preferences_custom_names[custom_name_id]
		custom_names[custom_name_id] = reject_bad_name(custom_names[custom_name_id],namedata["allow_numbers"])
		if(!custom_names[custom_name_id])
			custom_names[custom_name_id] = get_default_name(custom_name_id)

	if(!features["mcolor"] || features["mcolor"] == "#000")
		features["mcolor"] = pick("FFFFFF","7F7F7F", "7FFF7F", "7F7FFF", "FF7F7F", "7FFFFF", "FF7FFF", "FFFF7F")

	if(!features["ethcolor"] || features["ethcolor"] == "#000")
		features["ethcolor"] = GLOB.color_list_ethereal[pick(GLOB.color_list_ethereal)]

	randomise = SANITIZE_LIST(randomise)

	underwear_color = sanitize_hexcolor(underwear_color, 3, 0)
	skin_tone = sanitize_inlist(skin_tone, GLOB.skin_tones)
	playtime_reward_cloak = sanitize_integer(playtime_reward_cloak)
	features["mcolor"] = sanitize_hexcolor(features["mcolor"], 3, 0)
	features["ethcolor"] = copytext_char(features["ethcolor"], 1, 7)
	features["tail_lizard"] = sanitize_inlist(features["tail_lizard"], GLOB.tails_list_lizard)
	features["tail_human"] = sanitize_inlist(features["tail_human"], GLOB.tails_list_human, "None")
	features["snout"] = sanitize_inlist(features["snout"], GLOB.snouts_list)
	features["horns"] = sanitize_inlist(features["horns"], GLOB.horns_list)
	features["ears"] = sanitize_inlist(features["ears"], GLOB.ears_list, "None")
	features["frills"] = sanitize_inlist(features["frills"], GLOB.frills_list)
	features["spines"] = sanitize_inlist(features["spines"], GLOB.spines_list)
	features["body_markings"] = sanitize_inlist(features["body_markings"], GLOB.body_markings_list)
	features["feature_lizard_legs"] = sanitize_inlist(features["legs"], GLOB.legs_list, "Normal Legs")

	persistent_scars = sanitize_integer(persistent_scars)

	joblessrole = sanitize_integer(joblessrole, 1, 3, initial(joblessrole))
	//Validate job prefs
	for(var/j in job_preferences)
		if(job_preferences[j] != JP_LOW && job_preferences[j] != JP_MEDIUM && job_preferences[j] != JP_HIGH)
			job_preferences -= j

	all_quirks = SANITIZE_LIST(all_quirks)
	validate_quirks()

	return TRUE

/datum/preferences/proc/save_character()
	if(!path)
		return FALSE
	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/character[default_slot]"

	for (var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if (preference.savefile_identifier != PREFERENCE_CHARACTER)
			continue

		write_preference(preference, read_preference(preference.type))

	WRITE_FILE(S["version"] , SAVEFILE_VERSION_MAX) //load_character will sanitize any bad data, so assume up-to-date.)

	//Character
	WRITE_FILE(S["body_type"] , body_type)
	WRITE_FILE(S["skin_tone"] , skin_tone)
	WRITE_FILE(S["underwear_color"] , underwear_color)
	WRITE_FILE(S["playtime_reward_cloak"] , playtime_reward_cloak)
	WRITE_FILE(S["randomise"] , randomise)
	WRITE_FILE(S["phobia"], phobia)
	WRITE_FILE(S["feature_mcolor"] , features["mcolor"])
	WRITE_FILE(S["feature_ethcolor"] , features["ethcolor"])
	WRITE_FILE(S["feature_lizard_tail"] , features["tail_lizard"])
	WRITE_FILE(S["feature_human_tail"] , features["tail_human"])
	WRITE_FILE(S["feature_lizard_snout"] , features["snout"])
	WRITE_FILE(S["feature_lizard_horns"] , features["horns"])
	WRITE_FILE(S["feature_human_ears"] , features["ears"])
	WRITE_FILE(S["feature_lizard_frills"] , features["frills"])
	WRITE_FILE(S["feature_lizard_spines"] , features["spines"])
	WRITE_FILE(S["feature_lizard_body_markings"] , features["body_markings"])
	WRITE_FILE(S["feature_lizard_legs"] , features["legs"])
	WRITE_FILE(S["persistent_scars"] , persistent_scars)

	//Custom names
	for(var/custom_name_id in GLOB.preferences_custom_names)
		var/savefile_slot_name = custom_name_id + "_name" //TODO remove this
		WRITE_FILE(S[savefile_slot_name],custom_names[custom_name_id])

	WRITE_FILE(S["preferred_ai_core_display"] ,  preferred_ai_core_display)
	WRITE_FILE(S["prefered_security_department"] , prefered_security_department)

	//Jobs
	WRITE_FILE(S["joblessrole"] , joblessrole)
	//Write prefs
	WRITE_FILE(S["job_preferences"] , job_preferences)

	//Quirks
	WRITE_FILE(S["all_quirks"] , all_quirks)

	return TRUE


/proc/sanitize_keybindings(value)
	var/list/base_bindings = sanitize_islist(value,list())
	for(var/keybind_name in base_bindings)
		if (!(keybind_name in GLOB.keybindings_by_name))
			base_bindings -= keybind_name
	return base_bindings

#undef SAVEFILE_VERSION_MAX
#undef SAVEFILE_VERSION_MIN

#ifdef TESTING
//DEBUG
//Some crude tools for testing savefiles
//path is the savefile path
/client/verb/savefile_export(path as text)
	var/savefile/S = new /savefile(path)
	S.ExportText("/",file("[path].txt"))
//path is the savefile path
/client/verb/savefile_import(path as text)
	var/savefile/S = new /savefile(path)
	S.ImportText("/",file("[path].txt"))

#endif
