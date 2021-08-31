/// In the before times, toggles were all stored in one bitfield.
/// In order to preserve this existing data (and code) without massive
/// migrations, this middleware attempts to handle this in a way
/// transparent to the preferences UI itself.
/// In the future, the existing toggles data should just be migrated to
/// individual `/datum/preference/toggle`s.
/datum/preference_middleware/legacy_toggles
	// DO NOT ADD ANY NEW TOGGLES HERE!
	// Use `/datum/preference/toggle` instead.
	var/static/list/legacy_toggles = list(
		"admin_ignore_cult_ghost" = ADMIN_IGNORE_CULT_GHOST,
		"announce_login" = ANNOUNCE_LOGIN,
		"combohud_lighting" = COMBOHUD_LIGHTING,
		"deadmin_always" = DEADMIN_ALWAYS,
		"deadmin_antagonist" = DEADMIN_ANTAGONIST,
		"deadmin_position_head" = DEADMIN_POSITION_HEAD,
		"deadmin_position_security" = DEADMIN_POSITION_SECURITY,
		"deadmin_position_silicon" = DEADMIN_POSITION_SILICON,
		"disable_arrivalrattle" = DISABLE_ARRIVALRATTLE,
		"disable_deathrattle" = DISABLE_DEATHRATTLE,
		"member_public" = MEMBER_PUBLIC,
		"sound_adminhelp" = SOUND_ADMINHELP,
		"sound_ambience" = SOUND_AMBIENCE,
		"sound_announcements" = SOUND_ANNOUNCEMENTS,
		"sound_combatmode" = SOUND_COMBATMODE,
		"sound_endofround" = SOUND_ENDOFROUND,
		"sound_instruments" = SOUND_INSTRUMENTS,
		"sound_lobby" = SOUND_LOBBY,
		"sound_midi" = SOUND_MIDI,
		"sound_prayers" = SOUND_PRAYERS,
		"sound_ship_ambience" = SOUND_SHIP_AMBIENCE,
		"split_admin_tabs" = SPLIT_ADMIN_TABS,
	)

	var/list/legacy_chat_toggles = list(
		"chat_bankcard" = CHAT_BANKCARD,
		"chat_dead" = CHAT_DEAD,
		"chat_ghostears" = CHAT_GHOSTEARS,
		"chat_ghostlaws" = CHAT_GHOSTLAWS,
		"chat_ghostpda" = CHAT_GHOSTPDA,
		"chat_ghostradio" = CHAT_GHOSTRADIO,
		"chat_ghostsight" = CHAT_GHOSTSIGHT,
		"chat_ghostwhisper" = CHAT_GHOSTWHISPER,
		"chat_login_logout" = CHAT_LOGIN_LOGOUT,
		"chat_ooc" = CHAT_OOC,
		"chat_prayer" = CHAT_PRAYER,
		"chat_pullr" = CHAT_PULLR,
	)

// MOTHBLOCKS TODO: Don't send admin stuff to normal players.
// MOTHBLOCKS TODO: The auto_deadmin flags.
// MOTHBLOCKS TODO: member_public to only show when you are a BYOND member
/datum/preference_middleware/legacy_toggles/get_character_preferences(mob/user)
	var/list/new_game_preferences = list()

	for (var/toggle_name in legacy_toggles)
		new_game_preferences[toggle_name] = (preferences.toggles & legacy_toggles[toggle_name]) != 0

	for (var/toggle_name in legacy_chat_toggles)
		new_game_preferences[toggle_name] = (preferences.chat_toggles & legacy_chat_toggles[toggle_name]) != 0

	return list(
		PREFERENCE_CATEGORY_GAME_PREFERENCES = new_game_preferences,
	)

/datum/preference_middleware/legacy_toggles/pre_set_preference(mob/user, preference, value)
	var/legacy_flag = legacy_toggles[preference]
	if (!isnull(legacy_flag))
		if (value)
			preferences.toggles |= legacy_flag
		else
			preferences.toggles &= ~legacy_flag

		// I know this looks silly, but this is the only one that cares
		// and NO NEW LEGACY TOGGLES should ever be added.
		if (legacy_flag == SOUND_LOBBY)
			if (value && isnewplayer(user))
				user.client?.playtitlemusic()
			else
				user.stop_sound_channel(CHANNEL_LOBBYMUSIC)

		return TRUE

	var/legacy_chat_flag = legacy_chat_toggles[preference]
	if (!isnull(legacy_chat_flag))
		if (value)
			preferences.chat_toggles |= legacy_chat_flag
		else
			preferences.chat_toggles &= ~legacy_chat_flag

		return TRUE

	return FALSE
