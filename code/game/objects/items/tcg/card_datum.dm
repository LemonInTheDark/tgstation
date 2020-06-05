/datum/card
	///Unique ID, for use in lookups and (eventually) for persistence. MAKE SURE THIS IS UNIQUE FOR EACH CARD IN AS SERIES, OR THE ENTIRE SYSTEM WILL BREAK, AND I WILL BE VERY DISAPPOINTED.
	var/id = "coder"
	var/name = "Coder"
	var/desc = "Wow, a mint condition coder card! Better tell the Github all about this!"
	///This handles any extra rules for the card, i.e. extra attributes, special effects, etc. If you've played any other card game, you know how this works.
	var/rules = "There are no rules here. There is no escape. No Recall or Intervention can work in this place."
	var/icon //A variable initially used during loading to store info on how to build the icon, and afterwards used to store the icon
	///What it costs to summon this card to the battlefield.
	var/summoncost = -1
	///How hard this card hits (by default)
	var/power = 0
	///How hard this card can get hit (by default)
	var/resolve = 0
	///Someone please come up with a ruleset so I can comment this
	var/faction = "socks"
	///Used to define the behaviour the card uses during the game.
	var/cardtype ="C43a7u43?"
	///An extra descriptor for the card. Combined with the cardtype for a larger card descriptor, i.e. Creature- Xenomorph, Spell- Instant, that sort of thing. For creatures, this has no effect, for spells, this is important.
	var/cardsubtype = "Weeb"
	///Defines the series that the card originates from, this is *very* important for spawning the cards via packs.
	var/series = "coreset2020"
	///The rarity of this card, determines how much (or little) it shows up in packs. Rarities are common, uncommon, rare, epic, legendary and misprint.
	var/rarity = "uber rare to the extreme"

/datum/card/New(list/data = list(), list/templates = list())
	applyTemplates(data, templates)
	apply(data)

///For each var that the card datum and the json entry share, we set the datum var to the json entry
/datum/card/proc/apply(list/data)
	for(var/name in (vars & data))
		vars[name] = data[name]

///Applies a json file to a card datum
/datum/card/proc/applyTemplates(list/data, list/templates = list())
	apply(templates["default"])
	apply(templates[data["template"]])

///Loads all the card files
/proc/loadAllCardFiles(cardFiles, directory)
	var/list/templates = list()
	for(var/cardFile in cardFiles)
		loadCardFile(cardFile, directory, templates)

///Prints all the cards names
/proc/printAllCards()
	for(var/card_set in GLOB.cached_cards)
		message_admins("Printing the [card_set] set")
		for(var/card in GLOB.cached_cards[card_set]["ALL"])
			var/datum/card/toPrint = GLOB.cached_cards[card_set]["ALL"][card]
			message_admins(toPrint.name)

///Checks the passed type list for missing raritys, or raritys out of bounds
/proc/checkCardpacks(cardPackList)
	for(var/cardPack in cardPackList)
		var/obj/item/cardpack/pack = new cardPack()
		//Lets see if someone made a type yeah?
		if(!GLOB.cached_cards[pack.series])
			message_admins("[pack.series] does not have any related cards")
			continue
		for(var/card in GLOB.cached_cards[pack.series]["ALL"])
			var/datum/card/template = GLOB.cached_cards[pack.series]["ALL"][card]
			if(!(template.rarity in pack.rarity_table))
				message_admins("[pack.type] has a rarity [template.rarity] on the card [template.id] that does not exist")
				continue
		//Lets run a check to see if all the rarities exist that we want to exist exist
		for(var/I in pack.rarity_table)
			if(!GLOB.cached_cards[pack.series][I])
				message_admins("[pack.type] does not have the required rarity [I]")
		qdel(pack)

///Used to test open a large amount of cardpacks
/proc/checkCardDistribution(cardPack, batchSize, batchCount, guaranteed)
	var/totalCards = 0
	//Gotta make this look like an associated list so the implicit "does this exist" checks work proper later
	var/list/cardsByCount = list("" = 0)
	var/obj/item/cardpack/pack = new cardPack()
	for(var/index in 1 to batchCount)
		var/list/cards = pack.buildCardListWithRarity(batchSize, guaranteed)
		for(var/id in cards)
			totalCards++
			cardsByCount[id] += 1
	var/toSend = "Out of [totalCards] cards"
	for(var/id in sortList(cardsByCount, /proc/cmp_num_string_asc))
		if(id)
			var/datum/card/template = GLOB.cached_cards[pack.series]["ALL"][id]
			toSend += "\nID:[id] [template.name] [(cardsByCount[id] * 100) / totalCards]% Total:[cardsByCount[id]]"
	message_admins(toSend)
	qdel(pack)

/*
TODO Dumbass:
	make the color actually work
	add a spawn card debug verb
	make the filtering here simpler
	check to make sure the filtering works properly with multipial objects
	expand on icon system, add aliases
	make shit clean
	add aliases for everything we need
	cry
*/

/proc/buildCardIcon(list/data)
	var/list/iconPackets = data
	var/list/toStore = list()
	for(var/list/packet in iconPackets)
		var/image/piece
		piece = image(packet["source"], packet["state"])
		piece.color = packet["color"]
		toStore += piece
		message_admins("Applying [packet["color"]]")
	data.Cut()
	return toStore

///Empty the rarity cache so we can safely add new cards
/proc/clearCards()
	SStrading_card_game.loaded = FALSE
	GLOB.cached_cards = list()

///Reloads all card files
/proc/reloadAllCardFiles(cardFiles, directory)
	clearCards()
	loadAllCardFiles(cardFiles, directory)
	SStrading_card_game.loaded = TRUE

///Loads the contents of a json file into our global card list
/proc/loadCardFile(filename, directory = "strings/tcg")
	var/list/json = json_decode(file2text("[directory]/[filename]"))
	var/list/cards = json["cards"]
	var/list/templates = list()
	for(var/list/data in json["templates"])
		templates[data["template"]] = data
	for(var/list/data in cards)
		var/datum/card/c = new(data, templates)
		//Lets cache the id by rarity, for top speed lookup later
		if(!GLOB.cached_cards[c.series])
			GLOB.cached_cards[c.series] = list()
			GLOB.cached_cards[c.series]["ALL"] = list()
			GLOB.cached_cards[c.series]["icon"] = list()
			if(templates["flipped"])
				GLOB.cached_cards[c.series]["icon"]["flipped"] = buildCardIcon(templates["flipped"])
		if(!GLOB.cached_cards[c.series][c.rarity])
			GLOB.cached_cards[c.series][c.rarity] = list()
		GLOB.cached_cards[c.series][c.rarity] += c.id
		//And series too, why not, it's semi cheap
		GLOB.cached_cards[c.series]["ALL"][c.id] = c
		//Build the icon
		c.icon = buildCardIcon(c.icon)
		message_admins("Loaded [c.id]")
