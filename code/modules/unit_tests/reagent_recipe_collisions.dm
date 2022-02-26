

/datum/unit_test/reagent_recipe_collisions

/datum/unit_test/reagent_recipe_collisions/Run()
	build_chemical_reactions_lists()
	var/list/reactions = list()
	for(var/V in GLOB.chemical_reactions_list_reactant_index)
		reactions += GLOB.chemical_reactions_list_reactant_index[V]
	for(var/i in 1 to (reactions.len-1))
		for(var/i2 in (i+1) to reactions.len)
			var/datum/chemical_reaction/r1 = reactions[i]
			var/datum/chemical_reaction/r2 = reactions[i2]
			if(chem_recipes_do_conflict(r1, r2))
				Fail("Chemical recipe conflict between [r1.type] and [r2.type]")

/datum/unit_test/food_reaction_prevention

/datum/unit_test/food_reaction_prevention/Run()
	build_chemical_reactions_lists()
	var/list/food_paths = subtypesof(/obj/item/food)
	food_paths -= typesof(/obj/item/food/deepfryholder)
	food_paths -= typesof(/obj/item/food/grown)
	food_paths -= typesof(/obj/item/food/clothing)
	for(var/path in food_paths)
		var/obj/item/food/new_food = new path()
		if(!length(new_food.food_reagents) || new_food.food_flags & FOOD_IGNORE_REAGENTS_TEST)
			continue
		var/list/target_reagents = new_food.food_reagents.Copy()

		// Time for snowflake logic suffering
		if(istype(new_food, /obj/item/food/donut)) // I am sorry
			var/obj/item/food/donut/new_nut = new_food
			if(new_nut.is_decorated)
				target_reagents[/datum/reagent/consumable/sprinkles] += 1

		var/datum/reagents/food_reagents = new_food.reagents
		food_reagents.flags |= REAGENT_HOLDER_INSTANT_REACT
		food_reagents.handle_reactions() // Let it react if it has anything to react with

		for(var/type in target_reagents)
			var/target_amount = target_reagents[type]
			var/datum/reagent/existing_reagent = food_reagents.has_reagent(type)
			var/amount_left = 0
			if(existing_reagent)
				amount_left = existing_reagent.volume
			if(amount_left == target_amount)
				continue
			Fail("[path] doesn't have the right amount of [type] after spawning.\nHas [amount_left]u, but should have [target_amount]u.")

		for(var/datum/reagent/existing_reagent as anything in food_reagents.reagent_list)
			var/reagent_type = existing_reagent.type
			if(target_reagents[reagent_type]) // If we expect to have it, we don't care
				continue
			Fail("[path] has an unexpected reagent.\nHas [existing_reagent.volume]u, of [reagent_type].\nIs it reacting improperly?")

