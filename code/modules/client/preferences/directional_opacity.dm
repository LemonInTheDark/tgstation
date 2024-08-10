/datum/preference/toggle/directional_opacity
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "directional_opacity_pref"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/toggle/directional_opacity/apply_to_client(client/client, value)
	var/datum/hud/working_hud = client?.mob?.hud_used
	if(!working_hud)
		return
	for(var/atom/movable/screen/plane_master/darkness_mask/mask as anything in working_hud.get_true_plane_masters(DARKNESS_MASK_PLANE))
		mask.show_to(client.mob)
