/datum/component/conditionally_transparent
	/// Delay used before starting to fade in
	var/transparency_delay
	/// Midpoint alpha to animate between when fading in
	var/in_midpoint_alpha
	/// Alpha to use when invisible
	var/transparent_alpha
	/// Delay used before starting to fade in
	var/opacity_delay
	/// Midpoint alpha to animate between when fading out
	var/out_midpoint_alpha
	/// The class of "object" we behave as
	/// Used to conditionally accept clicks
	var/click_class
	var/obj/effect/overlay/mouse_listener/mouse_hook
	var/transparency_requested = FALSE
	var/currently_transparent = FALSE

/datum/component/conditionally_transparent/Initialize(
	list/transparent_signals,
	list/opaque_signals,
	start_transparent,
	transparency_delay,
	in_midpoint_alpha,
	transparent_alpha,
	opacity_delay,
	out_midpoint_alpha,
	click_class,
	click_layer,
)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	var/atom/atom_parent = parent
	src.transparency_delay = transparency_delay
	src.in_midpoint_alpha = in_midpoint_alpha
	src.transparent_alpha = transparent_alpha
	src.opacity_delay = opacity_delay
	src.out_midpoint_alpha = out_midpoint_alpha
	src.click_class = click_class
	mouse_hook = new(atom_parent, src)
	mouse_hook.render_source = "*conditional_transparency_catch_[atom_parent.dir]_[click_class]"
	mouse_hook.name = atom_parent.name
	mouse_hook.layer = click_layer

	if(start_transparent)
		transparency_requested = TRUE
		atom_parent.alpha = transparent_alpha
		atom_parent.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		currently_transparent = TRUE
	RegisterSignal(atom_parent, COMSIG_ATOM_UPDATE_APPEARANCE, PROC_REF(appearance_updated))
	RegisterSignal(atom_parent, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(dir_changed))
	RegisterSignals(atom_parent, transparent_signals, PROC_REF(attempt_transparent))
	RegisterSignals(atom_parent, opaque_signals, PROC_REF(attempt_opacity))

/datum/component/conditionally_transparent/Destroy(force)
	var/atom/atom_parent = parent
	if(atom_parent.alpha == transparent_alpha)
		atom_parent.alpha = initial(atom_parent.alpha)
		atom_parent.mouse_opacity = initial(atom_parent.mouse_opacity)
	if(mouse_hook)
		QDEL_NULL(mouse_hook)
	return ..()

/datum/component/conditionally_transparent/proc/appearance_updated(datum/source, updates)
	SIGNAL_HANDLER
	var/atom/atom_parent = parent
	mouse_hook.name = atom_parent.name

/datum/component/conditionally_transparent/proc/dir_changed(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	mouse_hook.render_source = "*conditional_transparency_catch_[new_dir]_[click_class]"

/datum/component/conditionally_transparent/proc/attempt_transparent()
	SIGNAL_HANDLER
	transparency_requested = TRUE
	update_transparency()

/datum/component/conditionally_transparent/proc/attempt_opacity()
	SIGNAL_HANDLER
	transparency_requested = FALSE
	update_transparency()

/datum/component/conditionally_transparent/proc/update_transparency()
	var/should_be_transparent = transparency_requested
	if(should_be_transparent == currently_transparent)
		return
	if(should_be_transparent)
		make_transparent()
	else
		make_opaque()
	currently_transparent = should_be_transparent

/datum/component/conditionally_transparent/proc/make_transparent(datum/source)
	var/atom/atom_parent = parent
// Current CI version of spaceman doesn't support delay and bumping it makes tgs mad so we're gonna do this till ci matches 1.9
#ifndef SPACEMAN_DMM
	animate(atom_parent, alpha = in_midpoint_alpha, easing = QUAD_EASING, time = 0.7 SECONDS, delay = transparency_delay)
	animate(alpha = transparent_alpha, easing = QUAD_EASING, time = 0.3 SECONDS)
#endif
	addtimer(VARSET_CALLBACK(atom_parent, mouse_opacity, MOUSE_OPACITY_TRANSPARENT), transparency_delay + (1 SECONDS))

/datum/component/conditionally_transparent/proc/make_opaque(datum/source)
	var/atom/atom_parent = parent
#ifndef SPACEMAN_DMM
	animate(atom_parent, alpha = out_midpoint_alpha, easing = QUAD_EASING, time = 0.7 SECONDS, delay = opacity_delay)
	animate(alpha = 255, easing = QUAD_EASING, time = 0.3 SECONDS)
#endif
	addtimer(VARSET_CALLBACK(atom_parent, mouse_opacity, initial(atom_parent.mouse_opacity)), opacity_delay + (1 SECONDS))

#warn the untransparency needs to be conditional too, fucking vis tossing again here we GOOOO
#warn firedoors break when closed and reopened over glass airlocks sometimes, getting in a state where they won't be closable by hand without opening the airlock
/obj/effect/overlay/mouse_listener
	icon = null
	icon_state = null
	appearance_flags = parent_type::appearance_flags | RESET_ALPHA | RESET_COLOR
	vis_flags = VIS_INHERIT_DIR|VIS_INHERIT_PLANE
	anchored = TRUE
	plane = FLOAT_PLANE
	layer = FLOAT_LAYER
	pixel_z = 16 // Makes transparency work correctly cause INSERT SCREED ABOUT BIG ICON VIS CONTENTS HERE AHHHHHHHHH
	alpha = 1
	blend_mode = BLEND_OVERLAY
	var/datum/component/conditionally_transparent/owner
	/// List in the form WEAKREF(client) -> image of ourselves fully visible
	var/list/client_to_alpha_image = list()

/obj/effect/overlay/mouse_listener/Initialize(mapload, datum/component/conditionally_transparent/owner)
	. = ..()
	src.owner = owner
	// areas don't have vis contents so gotta do it like this
	var/atom/movable/lies_to_areas = loc
	lies_to_areas.vis_contents += src

/obj/effect/overlay/mouse_listener/Destroy(force)
	owner.mouse_hook = null
	owner = null
	return ..()

/obj/effect/overlay/mouse_listener/proc/enable_temporary_display(mob/update_for)
	var/client/our_client = update_for.client
	if(!our_client)
		return
	var/datum/weakref/client_ref = WEAKREF(our_client)
	if(client_to_alpha_image[client_ref])
		remove_client_image(client_ref, client_to_alpha_image[client_ref])

	// What follows is a sort of hackneed attempt to avoid ballooning these lists too large in the worst case scenario
	for(var/datum/weakref/ref as anything in client_to_alpha_image)
		if(!ref.resolve())
			client_to_alpha_image -= ref

	var/image/showing = image(loc = src)
	showing.appearance_flags |= RESET_ALPHA
	showing.alpha = 0
	client_to_alpha_image[client_ref] = showing
	showing.render_source = render_source
	our_client.images += showing

	animate(showing, alpha = owner.out_midpoint_alpha - owner.transparent_alpha, easing = QUAD_EASING, time = 0.5 SECONDS)
	animate(alpha = 255 - owner.transparent_alpha, easing = QUAD_EASING, time = 0.3 SECONDS)

/obj/effect/overlay/mouse_listener/proc/disable_temporary_display(mob/update_for)
	var/client/our_client = update_for.client
	var/datum/weakref/client_ref = WEAKREF(our_client)
	var/image/hiding = client_to_alpha_image[client_ref]
	if(!hiding)
		return
	animate(hiding, alpha = owner.in_midpoint_alpha - owner.transparent_alpha, easing = QUAD_EASING, time = 0.5 SECONDS)
	animate(alpha = 0, easing = QUAD_EASING, time = 0.3 SECONDS)
	// we pass both to avoid a race condition
	addtimer(CALLBACK(src, PROC_REF(remove_client_image), client_ref, hiding), 0.8 SECONDS)

/obj/effect/overlay/mouse_listener/proc/remove_client_image(datum/weakref/client_ref, hiding)
	if(client_to_alpha_image[client_ref] == hiding)
		client_to_alpha_image -= client_ref
	var/client/remove_from = client_ref.resolve()
	if(!remove_from)
		return
	remove_from.images -= hiding

// hooks to mirror any of our inputs onto our atom parent
// we intentionally do not define MouseMove as it would just be a waste
/obj/effect/overlay/mouse_listener/Click(location, control, params)
	loc.Click(location, control, params)

/obj/effect/overlay/mouse_listener/DblClick(location, control, params)
	loc.DblClick(location, control, params)

/obj/effect/overlay/mouse_listener/MouseDown(location, control, params)
    loc.MouseDown(location, control, params)

/obj/effect/overlay/mouse_listener/MouseUp(location,control,params)
	loc.MouseUp(location,control,params)

/obj/effect/overlay/mouse_listener/MouseDown(over_object,src_location,over_location,src_control,over_control,params)
	loc.MouseDrag(over_object,src_location,over_location,src_control,over_control,params)

/obj/effect/overlay/mouse_listener/MouseDrop(over_object,src_location,over_location,src_control,over_control,params)
	SHOULD_NOT_OVERRIDE(TRUE)
	disable_temporary_display(usr)
	loc.MouseDrop(over_object,src_location,over_location,src_control,over_control,params)

/obj/effect/overlay/mouse_listener/MouseEntered(location,control,params)
	enable_temporary_display(usr)
	loc.MouseEntered(location,control,params)

/obj/effect/overlay/mouse_listener/MouseExited(location,control,params)
	disable_temporary_display(usr)
	loc.MouseExited(location,control,params)

/obj/effect/overlay/mouse_listener/MouseWheel(delta_x, delta_y, location, control, params)
	loc.MouseWheel(delta_x, delta_y, location, control, params)
