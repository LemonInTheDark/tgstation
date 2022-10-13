
// Checks plants for broken tray icons. Use Advanced Proc Call to activate.
// Maybe some day it would be used as unit test.
// -------- IT IS NOW!
/datum/unit_test/plantgrowth/Run()
	var/list/states = cached_icon_states('icons/obj/hydroponics/growing.dmi')
	states |= cached_icon_states('icons/obj/hydroponics/growing_fruits.dmi')
	states |= cached_icon_states('icons/obj/hydroponics/growing_flowers.dmi')
	states |= cached_icon_states('icons/obj/hydroponics/growing_mushrooms.dmi')
	states |= cached_icon_states('icons/obj/hydroponics/growing_vegetables.dmi')
	var/list/paths = subtypesof(/obj/item/seeds) - /obj/item/seeds - typesof(/obj/item/seeds/sample) - /obj/item/seeds/lavaland

	for(var/seedpath in paths)
		var/obj/item/seeds/seed = new seedpath

		for(var/i in 1 to seed.growthstages)
			if(states["[seed.icon_grow][i]"])
				continue
			TEST_FAIL("[seed.name] ([seed.type]) lacks the [seed.icon_grow][i] icon!")

		if(!states[seed.icon_dead])
			TEST_FAIL("[seed.name] ([seed.type]) lacks the [seed.icon_dead] icon!")

		if(seed.icon_harvest) // mushrooms have no grown sprites, same for items with no product
			if(!states[seed.icon_harvest])
				TEST_FAIL("[seed.name] ([seed.type]) lacks the [seed.icon_harvest] icon!")
