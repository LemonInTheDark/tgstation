GLOBAL_LIST_INIT(objects_by_click_class, generate_click_class_objects())

/proc/generate_click_class_objects()
	var/list/objects_by_class = list()
	var/list/click_classes = list("firedoor", "blast_door", "shutter")
	for(var/class in click_classes)
		var/list/objects_in_class = list()
		for(var/cardinal in list(NORTH, SOUTH, EAST, WEST)) // Global context so we need to avoid order of init issues
			var/obj/click_catcher/catcher = new()
			catcher.icon_state = class
			catcher.dir = cardinal
			catcher.render_target = "*conditional_transparency_catch_[cardinal]_[class]"
			objects_in_class += catcher
		objects_by_class[class] = objects_in_class
	return objects_by_class

/obj/click_catcher
	icon = 'icons/effects/click_classes.dmi'
	icon_state = "firedoor"
	screen_loc = "1,1"

/datum/element/visibility_source

