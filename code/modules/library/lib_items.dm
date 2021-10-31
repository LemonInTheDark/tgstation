#define BOOKCASE_UNANCHORED 0
#define BOOKCASE_ANCHORED 1
#define BOOKCASE_FINISHED 2

GLOBAL_LIST_EMPTY(roundstart_books_by_area)

/* Library Items
 *
 * Contains:
 * Bookcase
 * Book
 * Barcode Scanner
 */

/*
 * Bookcase
 */

/obj/structure/bookcase
	name = "bookcase"
	icon = 'icons/obj/library.dmi'
	icon_state = "bookempty"
	desc = "A great place for storing knowledge."
	anchored = FALSE
	density = TRUE
	opacity = FALSE
	resistance_flags = FLAMMABLE
	max_integrity = 200
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, RAD = 0, FIRE = 50, ACID = 0)
	var/state = BOOKCASE_UNANCHORED
	/// When enabled, books_to_load number of random books will be generated for this bookcase
	var/load_random_books = FALSE
	/// The category of books to pick from when populating random books.
	var/random_category = null
	/// How many random books to generate.
	var/books_to_load = 0

/obj/structure/bookcase/Initialize(mapload)
	. = ..()
	if(!mapload || QDELETED(src))
		return
	set_anchored(TRUE)
	state = BOOKCASE_FINISHED
	for(var/obj/item/I in loc)
		if(!isbook(I))
			continue
		I.forceMove(src)
	update_appearance()
	SSlibrary.shelves_to_load += src

///Loads the shelf, both by allowing it to generate random items, and by adding its contents to a list used by library machines
/obj/structure/bookcase/proc/load_shelf()
	//Loads a random selection of books in from the db, adds a copy of their info to a global list
	//To send to library consoles as a starting inventory
	if(load_random_books)
		create_random_books(books_to_load, src, FALSE, random_category)
		update_appearance() //Make sure you look proper

	var/area/our_area = get_area(src)
	var/area_type = our_area.type //Save me from the dark

	if(!GLOB.roundstart_books_by_area[area_type])
		GLOB.roundstart_books_by_area[area_type] = list()

	//Time to populate that list
	var/list/books_in_area = GLOB.roundstart_books_by_area[area_type]
	for(var/obj/item/book/book in contents)
		var/datum/book_info/info = book.book_data
		books_in_area += info.return_copy()

/obj/structure/bookcase/examine(mob/user)
	. = ..()
	if(!anchored)
		. += span_notice("The <i>bolts</i> on the bottom are unsecured.")
	else
		. += span_notice("It's secured in place with <b>bolts</b>.")
	switch(state)
		if(BOOKCASE_UNANCHORED)
			. += span_notice("There's a <b>small crack</b> visible on the back panel.")
		if(BOOKCASE_ANCHORED)
			. += span_notice("There's space inside for a <i>wooden</i> shelf.")
		if(BOOKCASE_FINISHED)
			. += span_notice("There's a <b>small crack</b> visible on the shelf.")

/obj/structure/bookcase/set_anchored(anchorvalue)
	. = ..()
	if(isnull(.))
		return
	state = anchorvalue
	if(!anchorvalue) //in case we were vareditted or uprooted by a hostile mob, ensure we drop all our books instead of having them disappear till we're rebuild.
		var/atom/Tsec = drop_location()
		for(var/obj/I in contents)
			if(!isbook(I))
				continue
			I.forceMove(Tsec)
	update_appearance()

/obj/structure/bookcase/attackby(obj/item/I, mob/user, params)
	switch(state)
		if(BOOKCASE_UNANCHORED)
			if(I.tool_behaviour == TOOL_WRENCH)
				if(I.use_tool(src, user, 20, volume=50))
					to_chat(user, span_notice("You wrench the frame into place."))
					set_anchored(TRUE)
			else if(I.tool_behaviour == TOOL_CROWBAR)
				if(I.use_tool(src, user, 20, volume=50))
					to_chat(user, span_notice("You pry the frame apart."))
					deconstruct(TRUE)

		if(BOOKCASE_ANCHORED)
			if(istype(I, /obj/item/stack/sheet/mineral/wood))
				var/obj/item/stack/sheet/mineral/wood/W = I
				if(W.get_amount() >= 2)
					W.use(2)
					to_chat(user, span_notice("You add a shelf."))
					state = BOOKCASE_FINISHED
					update_appearance()
			else if(I.tool_behaviour == TOOL_WRENCH)
				I.play_tool_sound(src, 100)
				to_chat(user, span_notice("You unwrench the frame."))
				set_anchored(FALSE)

		if(BOOKCASE_FINISHED)
			var/datum/component/storage/STR = I.GetComponent(/datum/component/storage)
			if(isbook(I))
				if(!user.transferItemToLoc(I, src))
					return
				update_appearance()
			else if(STR)
				for(var/obj/item/T in I.contents)
					if(istype(T, /obj/item/book) || istype(T, /obj/item/spellbook))
						STR.remove_from_storage(T, src)
				to_chat(user, span_notice("You empty \the [I] into \the [src]."))
				update_appearance()
			else if(istype(I, /obj/item/pen))
				if(!user.is_literate())
					to_chat(user, span_notice("You scribble illegibly on the side of [src]!"))
					return
				var/newname = stripped_input(user, "What would you like to title this bookshelf?")
				if(!user.canUseTopic(src, BE_CLOSE))
					return
				if(!newname)
					return
				else
					name = "bookcase ([sanitize(newname)])"
			else if(I.tool_behaviour == TOOL_CROWBAR)
				if(contents.len)
					to_chat(user, span_warning("You need to remove the books first!"))
				else
					I.play_tool_sound(src, 100)
					to_chat(user, span_notice("You pry the shelf out."))
					new /obj/item/stack/sheet/mineral/wood(drop_location(), 2)
					state = BOOKCASE_ANCHORED
					update_appearance()
			else
				return ..()

/obj/structure/bookcase/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!istype(user))
		return
	if(contents.len)
		var/obj/item/book/choice = input(user, "Which book would you like to remove from the shelf?") as null|obj in sortNames(contents.Copy())
		if(choice)
			if(!(user.mobility_flags & MOBILITY_USE) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || !in_range(loc, user))
				return
			if(ishuman(user))
				if(!user.get_active_held_item())
					user.put_in_hands(choice)
			else
				choice.forceMove(drop_location())
			update_appearance()

/obj/structure/bookcase/deconstruct(disassembled = TRUE)
	var/atom/Tsec = drop_location()
	new /obj/item/stack/sheet/mineral/wood(Tsec, 4)
	for(var/obj/item/I in contents)
		if(!isbook(I)) //Wake me up inside
			continue
		I.forceMove(Tsec)
	return ..()

/obj/structure/bookcase/update_icon_state()
	if(state == BOOKCASE_UNANCHORED || state == BOOKCASE_ANCHORED)
		icon_state = "bookempty"
		return ..()
	var/amount = contents.len
	icon_state = "book-[clamp(amount, 0, 5)]"
	return ..()

/obj/structure/bookcase/manuals/engineering
	name = "engineering manuals bookcase"

/obj/structure/bookcase/manuals/engineering/Initialize()
	new /obj/item/book/manual/wiki/engineering_construction(src)
	new /obj/item/book/manual/wiki/engineering_hacking(src)
	new /obj/item/book/manual/wiki/engineering_guide(src)
	new /obj/item/book/manual/wiki/engineering_singulo_tesla(src)
	new /obj/item/book/manual/wiki/robotics_cyborgs(src)
	return ..()

/obj/structure/bookcase/manuals/research_and_development
	name = "\improper R&D manuals bookcase"

/obj/structure/bookcase/manuals/research_and_development/Initialize()
	new /obj/item/book/manual/wiki/research_and_development(src)
	return ..()

/*
 * Book
 */
///A datum which contains all the metadata of a book
/datum/book_info
	///The title of the book
	var/title
	///The "author" of the book
	var/author
	///The info inside the book
	var/content

/datum/book_info/New(_title, _author, _content)
	title = _title
	author = _author
	content = _content

/datum/book_info/proc/set_title(_title, legacy = FALSE)
	if(legacy)
		title = _title
		return
	title = reject_bad_text(trim(html_encode(_title), 200))

/datum/book_info/proc/set_author(_author, legacy = FALSE)
	if(legacy)
		author = _author
		return
	author = trim(html_encode(_author), MAX_NAME_LEN)

/datum/book_info/proc/set_content(_content, legacy = FALSE) //Legacy should only be used for books read from the db. It is unsafe in all other cases
	if(legacy)
		content = _content
		return
	content = trim(html_encode(_content), MAX_PAPER_LENGTH)

///Returns a copy of the book_info datum
/datum/book_info/proc/return_copy()
	var/datum/book_info/copycat = new(title, author, content)
	return copycat

///Modify an existing book_info datum to match your data
/datum/book_info/proc/copy_into(datum/book_info/copycat)
	copycat.set_title(title, legacy = TRUE)
	copycat.set_author(author, legacy = TRUE)
	copycat.set_content(content, legacy = TRUE)
	return copycat

/datum/book_info/proc/compare(datum/book_info/cmp_with)
	if(author != cmp_with.author)
		return FALSE
	if(title != cmp_with.title)
		return FALSE
	if(content != cmp_with.content)
		return FALSE
	return TRUE

/obj/item/book
	name = "book"
	icon = 'icons/obj/library.dmi'
	icon_state ="book"
	worn_icon_state = "book"
	desc = "Crack it open, inhale the musk of its pages, and learn something new."
	throw_speed = 1
	throw_range = 5
	w_class = WEIGHT_CLASS_NORMAL  //upped to three because books are, y'know, pretty big. (and you could hide them inside eachother recursively forever)
	attack_verb_continuous = list("bashes", "whacks", "educates")
	attack_verb_simple = list("bash", "whack", "educate")
	resistance_flags = FLAMMABLE
	drop_sound = 'sound/items/handling/book_drop.ogg'
	pickup_sound =  'sound/items/handling/book_pickup.ogg'
	///Game time in 1/10th seconds
	var/due_date = 0
	///false - Normal book, true - Should not be treated as normal book, unable to be copied, unable to be modified
	var/unique = FALSE
	/// Specific window size for the book, i.e: "1920x1080", Size x Width
	var/window_size = null
	///The initial title, for use in var editing and such
	var/starting_title
	///The initial author, for use in var editing and such
	var/starting_author
	///The initial bit of content, for use in var editing and such
	var/starting_content
	///The packet of information that describes this book
	var/datum/book_info/book_data

/obj/item/book/Initialize()
	. = ..()
	book_data = new(starting_title, starting_author, starting_content)

/obj/item/book/attack_self(mob/user)
	if(!user.can_read(src))
		return
	user.visible_message(span_notice("[user] opens a book titled \"[book_data.title]\" and begins reading intently."))
	SEND_SIGNAL(user, COMSIG_ADD_MOOD_EVENT, "book_nerd", /datum/mood_event/book_nerd)
	on_read(user)

/obj/item/book/proc/on_read(mob/user)
	if(book_data?.content)
		user << browse("<meta charset=UTF-8><TT><I>Penned by [book_data.author].</I></TT> <BR>" + "[book_data.content]", "window=book[window_size != null ? ";size=[window_size]" : ""]")
		onclose(user, "book")
	else
		to_chat(user, span_notice("This book is completely blank!"))


/obj/item/book/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/pen))
		if(user.is_blind())
			to_chat(user, span_warning("As you are trying to write on the book, you suddenly feel very stupid!"))
			return
		if(unique)
			to_chat(user, span_warning("These pages don't seem to take the ink well! Looks like you can't modify it."))
			return
		var/literate = user.is_literate()
		if(!literate)
			to_chat(user, span_notice("You scribble illegibly on the cover of [src]!"))
			return
		var/choice = tgui_input_list(usr, "What would you like to change?",,list("Title", "Contents", "Author", "Cancel"))
		if(!user.canUseTopic(src, BE_CLOSE, literate))
			return
		switch(choice)
			if("Title")
				var/newtitle = reject_bad_text(stripped_input(user, "Write a new title:"))
				if(!user.canUseTopic(src, BE_CLOSE, literate))
					return
				if (length_char(newtitle) > 30)
					to_chat(user, span_warning("That title won't fit on the cover!"))
					return
				if(!newtitle)
					to_chat(user, span_warning("That title is invalid."))
					return
				name = newtitle
				book_data.set_title(newtitle)
			if("Contents")
				var/content = stripped_input(user, "Write your book's contents (HTML NOT allowed):", max_length= MAX_PAPER_LENGTH)
				if(!user.canUseTopic(src, BE_CLOSE, literate))
					return
				if(!content)
					to_chat(user, span_warning("The content is invalid."))
					return
				book_data.set_content(content)
			if("Author")
				var/author = stripped_input(user, "Write the author's name:")
				if(!user.canUseTopic(src, BE_CLOSE, literate))
					return
				if(!author)
					to_chat(user, span_warning("The name is invalid."))
					return
				book_data.set_author(author)
			else
				return

	else if(istype(I, /obj/item/barcodescanner))
		var/obj/item/barcodescanner/scanner = I
		if(!scanner.computer)
			to_chat(user, span_alert("[scanner]'s screen flashes: 'No associated computer found!'"))
		else
			switch(scanner.mode)
				if(0)
					scanner.book = src
					to_chat(user, span_notice("[scanner]'s screen flashes: 'Book stored in buffer.'"))
				if(1)
					scanner.book = src
					scanner.computer.buffer_book = book_data.return_copy()
					to_chat(user, span_notice("[scanner]'s screen flashes: 'Book stored in buffer. Book title stored in associated computer buffer.'"))
				if(2)
					scanner.book = src
					var/list/checkouts = scanner.computer.checkouts
					for(var/checkout_ref in checkouts)
						var/datum/borrowbook/maybe_ours = checkouts[checkout_ref]
						if(book_data.compare(maybe_ours.book_data))
							checkouts -= checkout_ref
							scanner.computer.checkout_update()
							to_chat(user, span_notice("[scanner]'s screen flashes: 'Book stored in buffer. Book has been checked in.'"))
							return
					to_chat(user, span_notice("[scanner]'s screen flashes: 'Book stored in buffer. No active check-out record found for current title.'"))
				if(3)
					scanner.book = src
					var/datum/book_info/our_copy = book_data.return_copy()
					scanner.computer.inventory[ref(our_copy)] = our_copy
					scanner.computer.inventory_update()
					to_chat(user, span_notice("[scanner]'s screen flashes: 'Book stored in buffer. Title added to general inventory.'"))

	else if((istype(I, /obj/item/kitchen/knife) || I.tool_behaviour == TOOL_WIRECUTTER) && !(flags_1 & HOLOGRAM_1))
		to_chat(user, span_notice("You begin to carve out [book_data.title]..."))
		if(do_after(user, 30, target = src))
			to_chat(user, span_notice("You carve out the pages from [book_data.title]! You didn't want to read it anyway."))
			var/obj/item/storage/book/carved_out = new
			carved_out.name = src.name
			carved_out.title = book_data.title
			carved_out.icon_state = src.icon_state
			if(user.is_holding(src))
				qdel(src)
				user.put_in_hands(carved_out)
				return
			else
				carved_out.forceMove(drop_location())
				qdel(src)
				return
		return
	else
		..()


/*
 * Barcode Scanner
 */
/obj/item/barcodescanner
	name = "barcode scanner"
	icon = 'icons/obj/library.dmi'
	icon_state ="scanner"
	desc = "A fabulous tool if you need to scan a barcode."
	throw_speed = 3
	throw_range = 5
	w_class = WEIGHT_CLASS_TINY
	var/obj/machinery/computer/libraryconsole/bookmanagement/computer //Associated computer - Modes 1 to 3 use this
	var/obj/item/book/book //Currently scanned book
	var/mode = 0 //0 - Scan only, 1 - Scan and Set Buffer, 2 - Scan and Attempt to Check In, 3 - Scan and Attempt to Add to Inventory

/obj/item/barcodescanner/attack_self(mob/user)
	mode += 1
	if(mode > 3)
		mode = 0
	to_chat(user, "[src] Status Display:")
	var/modedesc
	switch(mode)
		if(0)
			modedesc = "Scan book to local buffer."
		if(1)
			modedesc = "Scan book to local buffer and set associated computer buffer to match."
		if(2)
			modedesc = "Scan book to local buffer, attempt to check in scanned book."
		if(3)
			modedesc = "Scan book to local buffer, attempt to add book to general inventory."
		else
			modedesc = "ERROR"
	to_chat(user, " - Mode [mode] : [modedesc]")
	if(computer)
		to_chat(user, "<font color=green>Computer has been associated with this unit.</font>")
	else
		to_chat(user, "<font color=red>No associated computer found. Only local scans will function properly.</font>")
	to_chat(user, "\n")


#undef BOOKCASE_UNANCHORED
#undef BOOKCASE_ANCHORED
#undef BOOKCASE_FINISHED
