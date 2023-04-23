/obj/machinery/light/broken
	status = LIGHT_BROKEN
	icon_state = "tube-broken"

/obj/machinery/light/built
	icon_state = "tube-empty"
	start_with_cell = FALSE

/obj/machinery/light/built/Initialize(mapload)
	. = ..()
	status = LIGHT_EMPTY
	update(0)

/obj/machinery/light/no_nightlight
	nightshift_enabled = FALSE

/obj/machinery/light/warm
	bulb_colour = "#fae5c1"

/obj/machinery/light/warm/no_nightlight
	nightshift_allowed = FALSE

/obj/machinery/light/cold
	bulb_colour = LIGHT_COLOR_FAINT_BLUE
	nightshift_light_color = LIGHT_COLOR_FAINT_BLUE

/obj/machinery/light/cold/no_nightlight
	nightshift_allowed = FALSE

/obj/machinery/light/red
	bulb_colour = "#FF3232"
	nightshift_allowed = FALSE
	no_low_power = TRUE

/obj/machinery/light/red/dim
	brightness = 4
	bulb_power = 0.7
	fire_brightness = 2

/obj/machinery/light/blacklight
	bulb_colour = "#A700FF"
	nightshift_allowed = FALSE

/obj/machinery/light/dim
	nightshift_allowed = FALSE
	bulb_colour = "#FFDDCC"
	bulb_power = 0.6

// the smaller bulb light fixture

/obj/machinery/light/small
	icon_state = "bulb"
	base_state = "bulb"
	fitting = "bulb"
	brightness = 4
	nightshift_brightness = 4
	fire_brightness = 3
	bulb_colour = "#FFD6AA"
	fire_colour = "#bd3f46"
	desc = "A small lighting fixture."
	light_type = /obj/item/light/bulb

/obj/machinery/light/small/broken
	status = LIGHT_BROKEN
	icon_state = "bulb-broken"

/obj/machinery/light/small/built
	icon_state = "bulb-empty"
	start_with_cell = FALSE

/obj/machinery/light/small/built/Initialize(mapload)
	. = ..()
	status = LIGHT_EMPTY
	update(0)

/obj/machinery/light/small/red
	bulb_colour = "#FF3232"
	no_low_power = TRUE
	nightshift_allowed = FALSE
	fire_colour = "#ff1100"

/obj/machinery/light/small/red/dim
	brightness = 2
	bulb_power = 0.8
	fire_brightness = 2

/obj/machinery/light/small/blacklight
	bulb_colour = "#A700FF"
	nightshift_allowed = FALSE
	brightness = 4
	fire_brightness = 3
	fire_colour = "#d400ff"

// -------- Directional presets
// The directions are backwards on the lights we have now
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light)

// ---- Broken tube
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/broken)

// ---- Tube construct
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/structure/light_construct)

// ---- Tube frames
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/built)

// ---- No nightlight tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/no_nightlight)

// ---- Warm light tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/warm)

// ---- No nightlight warm light tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/warm/no_nightlight)

// ---- Cold light tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/cold)

// ---- No nightlight cold light tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/cold/no_nightlight)

// ---- Red tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/red)

// ---- Red dim tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/red/dim)

// ---- Blacklight tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/blacklight)

// ---- Dim tubes
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/dim)


// -------- Bulb lights
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/small)

// ---- Bulb construct
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/structure/light_construct/small)

// ---- Bulb frames
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/small/built)

// ---- Broken bulbs
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/small/broken)

// ---- Red bulbs
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/small/red)

// ---- Red dim bulbs
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/small/red/dim)

// ---- Blacklight bulbs
WALL_MOUNT_DIRECTIONAL_HELPERS(/obj/machinery/light/small/blacklight)
