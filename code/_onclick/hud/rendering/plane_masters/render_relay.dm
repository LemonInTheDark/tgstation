/**
 * Custom rendering solution to allow for advanced effects
 * We (ab)use plane masters and render source/target to cheaply render 2+ planes as 1
 * if you want to read more read the _render_readme.md
 */
/atom/movable/render_plane_relay
	screen_loc = "CENTER"
	layer = -1
	plane = 0
	appearance_flags = PASS_MOUSE | NO_CLIENT_COLOR | KEEP_TOGETHER
	var/displayed = FALSE
	/// Our source plane master
	var/atom/movable/screen/plane_master/source
	/// Our target plane master
	var/atom/movable/screen/plane_master/target

/atom/movable/render_plane_relay/Destroy(force)
	. = ..()
	if(displayed)
		source.relay_removed()
		displayed = FALSE
	source.render_relay_planes -= plane
	source.relays -= src
	if(source.home)
		source.home.relays["[plane]"] -= src
	var/client/lad = source.home?.our_hud?.mymob?.canon_client
	if(lad)
		lad.screen -= src
	source = null
	target = null

/atom/movable/render_plane_relay/proc/sync_relay(client/owner)
	if(!source.displayed || (target && !target.displayed && source.should_hide_relay(plane)) || source.home.isolated_plane == source.plane)
		if(displayed)
			source.relay_removed()
		displayed = FALSE
		owner.screen -= src
	else
		if(!displayed)
			source.relay_activated()
		displayed = TRUE
		owner.screen += src
