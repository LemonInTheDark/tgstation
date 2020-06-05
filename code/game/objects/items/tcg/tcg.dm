
GLOBAL_LIST_EMPTY(cached_guar_rarity)
GLOBAL_LIST_EMPTY(cached_rarity_table)
//Global list of all cards by series, with cards cached by rarity to make those lookups faster
GLOBAL_LIST_EMPTY(cached_cards)

/obj/item/tcgcard
	name = "Coder"
	desc = "Wow, a mint condition coder card! Better tell the Github all about this!"
	icon = 'icons/obj/tcg.dmi'
	icon_state = "base"
	w_class = WEIGHT_CLASS_TINY
	 //Unique ID, for use in lookups and storage, used to index the global datum list where the rest of the card's info is stored
	var/id = "code"
	//Used along with the id for lookup
	var/series = "coderbus"
	///Is the card flipped?
	var/flipped = FALSE

/obj/item/tcgcard/Initialize(mapload, datum_series, datum_id)
	. = ..()
	transform = matrix(0.3,0,0,0,0.3,0)
	//If they are passed as null let's replace them with the vars on the card. this also means we can allow for map loaded ccards
	if(!datum_series)
		datum_series = series
	if(!datum_id)
		datum_id = id
	var/list/L = GLOB.cached_cards[datum_series]
	if(!L)
		return
	var/datum/card/temp = L["ALL"][datum_id]
	if(!temp)
		return
	name = temp.name
	desc = temp.desc
	overlays = temp.icon
	id = temp.id
	series = temp.series

/obj/item/tcgcard/attack_self(mob/user)
	. = ..()
	to_chat(user, "<span_class='notice'>You turn the card over.</span>")
	if(!flipped)
		name = "Trading Card"
		desc = "It's the back of a trading card... no peeking!"
		overlays = GLOB.cached_cards[series]["icon"]["flipped"]
	else
		var/datum/card/template = GLOB.cached_cards[series]["ALL"][id]
		name = template.name
		desc = template.desc
		overlays = template.icon
	flipped = !flipped

/obj/item/tcgcard/equipped(mob/user, slot, initial)
	. = ..()
	transform = matrix()

/obj/item/tcgcard/dropped(mob/user, silent)
	. = ..()
	transform = matrix(0.3,0,0,0,0.3,0)

/obj/item/cardpack
	name = "Trading Card Pack: Coder"
	desc = "Contains six complete fuckups by the coders. Report this on github please!"
	icon = 'icons/obj/tcg.dmi'
	icon_state = "cardback_nt"
	w_class = WEIGHT_CLASS_TINY
	///The card series to look in
	var/series = "MEME"
	///Chance of the pack having a coin in it out of 10
	var/contains_coin = -1
	///The amount of cards to draw from the rarity table
	var/card_count = 5
	///The rarity table, the set must contain at least one of each
	var/list/rarity_table = list(
		"uncommon" = 1)
	///The amount of cards to draw from the guarenteed rarity table
	var/guaranteed_count = 1
	///The guaranteed rarity table, acts about the same as the rarity table. it can have as many or as few raritys as you'd like
	var/list/guar_rarity = list(
		"uncommon" = 1)

/obj/item/cardpack/series_one
	name = "Trading Card Pack: Series 1"
	desc = "Contains six cards of varying rarity from the 2560 Core Set. Collect them all!"
	icon = 'icons/obj/tcg.dmi'
	icon_state = "cardpack_series1"
	series = "coreset2020"
	contains_coin = 10

/obj/item/cardpack/resin
	name = "Trading Card Pack: Resin Frontier Booster Pack"
	desc = "Contains six cards of varying rarity from the Resin Frontier set. Collect them all!"
	icon = 'icons/obj/tcg_xenos.dmi'
	icon_state = "cardpack_resin"
	series = "resinfront"
	contains_coin = 0
	rarity_table = list(
		"uncommon" = 1)

/obj/item/cardpack/Initialize()
	. = ..()
	transform = matrix(0.4,0,0,0,0.4,0)
	//Pass by refrance moment
	//This lets us only have one rarity table per pack, badmins beware
	if(GLOB.cached_rarity_table[type])
		rarity_table = GLOB.cached_rarity_table[type]
	else
		GLOB.cached_rarity_table[type] = rarity_table
	if(GLOB.cached_guar_rarity[type])
		guar_rarity = GLOB.cached_guar_rarity[type]
	else
		GLOB.cached_guar_rarity[type] = guar_rarity

/obj/item/cardpack/equipped(mob/user, slot, initial)
	. = ..()
	transform = matrix()

/obj/item/cardpack/dropped(mob/user, silent)
	. = ..()
	transform = matrix(0.4,0,0,0,0.4,0)

/obj/item/cardpack/attack_self(mob/user)
	. = ..()
	var/list/cards = buildCardListWithRarity(card_count, guaranteed_count)
	for(var/id in cards)
		//Makes a new card based of the series of the pack.
		message_admins(id)
		new /obj/item/tcgcard(get_turf(user), series, id)
	to_chat(user, "<span_class='notice'>Wow! Check out these cards!</span>")
	new /obj/effect/decal/cleanable/wrapping(get_turf(user))
	playsound(loc, 'sound/items/poster_ripped.ogg', 20, TRUE)
	if(prob(contains_coin))
		to_chat(user, "<span_class='notice'>...and it came with a flipper, too!</span>")
		new /obj/item/coin/thunderdome(get_turf(user))
	qdel(src)

/obj/item/coin/thunderdome
	name = "Thunderdome Flipper"
	desc = "A Thunderdome TCG flipper, for deciding who gets to go first. Also conveniently acts as a counter, for various purposes."
	icon = 'icons/obj/tcg.dmi'
	icon_state = "coin_nanotrasen"
	custom_materials = list(/datum/material/plastic = 400)
	material_flags = NONE
	sideslist = list("nanotrasen", "syndicate")

/obj/item/coin/thunderdome/Initialize()
	. = ..()
	transform = matrix(0.4,0,0,0,0.4,0)

/obj/item/coin/thunderdome/equipped(mob/user, slot, initial)
	. = ..()
	transform = matrix()

/obj/item/coin/thunderdome/dropped(mob/user, silent)
	. = ..()
	transform = matrix(0.4,0,0,0,0.4,0)

///Returns a list of cards ids of card_cnt weighted by rarity from the pack's tables that have matching series, with gnt_cnt of the guarenteed table.
/obj/item/cardpack/proc/buildCardListWithRarity(card_cnt, rarity_cnt)
	var/list/toReturn = list()
	//You can always get at least one of some rarity
	toReturn += returnCardsByRarity(rarity_cnt, guar_rarity)
	toReturn += returnCardsByRarity(card_cnt, rarity_table)
	return toReturn

///Returns a list of card datums of the length cardCount that match a random rarity weighted by rarity_table[]
/obj/item/cardpack/proc/returnCardsByRarity(cardCount, list/rarity_table)
	var/list/toReturn = list()
	for(var/card in 1 to cardCount)
		var/rarity = 0
		//Some number between 1 and the sum of all values in the list
		var/weight = 0
		for(var/chance in rarity_table)
			weight += rarity_table[chance]
		var/random = rand(weight)
		for(var/bracket in rarity_table)
			//Steals blatently from pickweight(), sorry buddy I need the index
			random -= rarity_table[bracket]
			if(random <= 0)
				rarity = bracket
				break
		//What we're doing here is using the cached the results of the rarity we find.
		//This allows us to only have to run this once per rarity, ever.
		//Unless you reload the cards of course, in which case we have to do this again.
		var/list/cards = GLOB.cached_cards[series][rarity]
		if(cards.len)
			toReturn += pick(cards)
		else
			//If we still don't find anything yell into the void. Lazy coders.
			log_runtime("The index [rarity] of rarity_table does not exist in the global cache")
	return toReturn

