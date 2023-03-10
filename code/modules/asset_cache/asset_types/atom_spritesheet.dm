/// A spritesheet made up of references to atoms.
/// The atoms must remain valid for the lifetime of the spritesheet.
/// This is currently locked behind 515. You can test it by defining EXPERIMENT_515_ATOM_SPRITESHEETS.
// MBTODO: Graceful fallback to /datum/asset/spritesheet for 514 clients?
// MBTODO: Should we error if anything we're showing qdels?
/datum/asset/atom_spritesheet
	_abstract = /datum/asset/atom_spritesheet

	/// Name of the spritesheet, sent to the client.
	var/name

	/// name -> atom
	var/list/atoms = list()

/datum/asset/atom_spritesheet/register()
	SHOULD_NOT_OVERRIDE(TRUE)

#ifndef EXPERIMENT_515_ATOM_SPRITESHEETS
	CRASH("EXPERIMENT_515_ATOM_SPRITESHEETS must be defined to use atom spritesheets")
#endif

	ASSERT(!isnull(name), "[type] has no name")

	create_spritesheets()
	realize()

/// Ran on register, override in your subtype, then call insert.
/datum/asset/atom_spritesheet/proc/create_spritesheets()
	PROTECTED_PROC(TRUE)

	CRASH("[type] does not implement create_spritesheets()")

/// Inserts an atom into the spritesheet.
/// Once inserted, an atom should never change size.
/datum/asset/atom_spritesheet/proc/insert(name, atom/atom)
	SHOULD_NOT_OVERRIDE(TRUE)
	PROTECTED_PROC(TRUE)

	ASSERT(istype(atom), "[type] insert() called with non-atom [atom]")
	atoms[name] = atom

/datum/asset/atom_spritesheet/proc/realize()
	PRIVATE_PROC(TRUE)

	var/list/lines = list()
	for (var/atom_name in atoms)
		var/atom/display = atoms[atom_name]

		/*
		var/icon/icon = icon(display.icon)
		var/width = icon.Width()
		var/height = icon.Height()

		var/size_id = "[width]x[height]"

		if (!(size_id in hit_sizes))
			hit_sizes += size_id
			size_classes += ".[atom_name][size_id] {\
				display: inline-block; \
				width: [width]px; \
				height: [height]px; \
			}"
		*/

		lines += "<img src='\ref[display]' />"

	var/html = lines.Join("")

	var/resource_name = "spritesheet_[name].html"
	var/filename = "data/spritesheets/[resource_name]"
	rustg_file_write(html, filename)
	SSassets.transport.register_asset(resource_name, fcopy_rsc(filename))

/datum/asset/atom_spritesheet/send(client/client)
	var/datum/asset_cache_item/asset_cache = SSassets.cache["spritesheet_[name].html"]
	var/atom/movable/shown = new()
	client.screen += shown
	var/cnt = 0
	for(var/key in atoms)
		if(cnt >= 10)
			break
		cnt++
		client << output(atoms[key], "THISCONTROLDOESN'TEXIST")

		//shown.vis_contents += atoms[key]
	client << browse(asset_cache.resource, "window=[name]")
