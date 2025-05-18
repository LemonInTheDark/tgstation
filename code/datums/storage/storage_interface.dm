/// Datum tracker for storage UI
/datum/storage_interface
	/// UI elements for this theme
	var/atom/movable/screen/close/closer
	var/atom/movable/screen/storage/cell/cells_full
	var/atom/movable/screen/storage/cell/cells_remainder
	var/atom/movable/screen/unusable_storage/cells_untouchable
	var/atom/movable/screen/storage/corner/corner_top_left
	var/atom/movable/screen/storage/corner/top_right/corner_top_right
	var/atom/movable/screen/storage/corner/bottom_left/corner_bottom_left
	var/atom/movable/screen/storage/corner/bottom_right/corner_bottom_right
	var/atom/movable/screen/storage/rowjoin/rowjoin_left
	var/atom/movable/screen/storage/rowjoin/right/rowjoin_right
	var/atom/movable/screen/storage_maptext/weight_maptext
	var/list/atom/movable/screen/storage_pip/pips = list()

	// Cache of pip inputs, avoids doing a bunch of appearance loc work for no reason
	var/cached_pips_per_row = -1
	var/cached_pip_start_pixel_x = -1
	var/cached_pip_start_pixel_y = -1
	var/cached_pip_count = -1
	var/cached_pips_hidden = FALSE
	var/cached_pip_target = 0
	var/cached_min_highlighted_pip = 0
	var/cached_max_highlighted_pip = 0

	/// Weakref to the item inside our parent whose weight we are currently displaying
	var/datum/weakref/weight_ref = null

	/// Storage that owns us
	var/datum/storage/parent_storage
	/// Mob that is viewing us
	var/mob/viewer

/datum/storage_interface/New(ui_style, parent_storage, mob/viewer)
	..()
	src.parent_storage = parent_storage
	src.viewer = viewer
	closer = new(null, null, parent_storage)
	cells_full = new(null, null, parent_storage)
	cells_remainder = new(null, null, parent_storage)
	cells_untouchable = new(null, null)
	corner_top_left = new(null, null, parent_storage)
	corner_top_right = new(null, null, parent_storage)
	corner_bottom_left = new(null, null, parent_storage)
	corner_bottom_right = new(null, null, parent_storage)
	rowjoin_left = new(null, null, parent_storage)
	rowjoin_right = new(null, null, parent_storage)
	weight_maptext = new(null, null)
	build_pips()
	update_style(ui_style)

/datum/storage_interface/Destroy(force)
	QDEL_NULL(cells_full)
	QDEL_NULL(cells_remainder)
	QDEL_NULL(cells_untouchable)
	QDEL_NULL(corner_top_left)
	QDEL_NULL(corner_top_right)
	QDEL_NULL(corner_bottom_left)
	QDEL_NULL(corner_bottom_right)
	QDEL_NULL(rowjoin_left)
	QDEL_NULL(rowjoin_right)
	QDEL_NULL(weight_maptext)
	QDEL_LIST(pips)
	parent_storage = null
	viewer = null
	return ..()

/datum/storage_interface/proc/update_style(ui_style)
	for (var/atom/movable/screen/ui_elem as anything in list_ui_elements())
		ui_elem.icon = ui_style

/// Returns all UI elements under this theme
/datum/storage_interface/proc/list_ui_elements()
	build_pips()
	var/list/atom/movable/screen/elements = list(
		cells_untouchable, cells_full, cells_remainder, corner_top_left,
		corner_top_right, corner_bottom_left, corner_bottom_right, rowjoin_left,
		rowjoin_right, closer, weight_maptext)
	elements += pips
	return elements

#define MAX_DISPLAYABLE_PIPS 74 // 2 layers
#define PIP_X_SPACING 2
#define PIP_Y_SPACING 1
#define PIP_WIDTH 4
#define PIP_HEIGHT 4
/datum/storage_interface/proc/build_pips()
	if(QDELETED(src))
		return
	// cache locally for sonic speeeeeeed
	var/list/pips = src.pips
	var/pip_target = min(parent_storage.max_total_storage, MAX_DISPLAYABLE_PIPS)
	var/pip_count = length(pips)
	if(pip_count == pip_target)
		return

	var/client/display_to = viewer?.client
	if(pip_count > pip_target)
		for(var/i in 1 to (pip_count - pip_target))
			var/atom/movable/screen/storage_pip/yeeted = pips[(pip_count - i) + 1]
			qdel(yeeted)
			display_to?.screen -= yeeted
		pips.Cut(pip_target + 1)
		return
	cached_pips_hidden = FALSE
	for(var/i in 1 to (pip_target - pip_count))
		var/atom/movable/screen/storage_pip/my_beloved = new(null, null)
		pips += my_beloved
		display_to?.screen += my_beloved

/datum/storage_interface/proc/position_pips(pips_per_row, pip_start_pixel_x, pip_start_pixel_y, pip_count)
	if(cached_pips_per_row == pips_per_row && cached_pip_start_pixel_x == pip_start_pixel_x && cached_pip_start_pixel_y == pip_start_pixel_y && cached_pip_count == pip_count)
		return
	cached_pips_hidden = FALSE
	cached_pips_per_row = pips_per_row
	cached_pip_start_pixel_x = pip_start_pixel_x
	cached_pip_start_pixel_y = pip_start_pixel_y
	cached_pip_count = pip_count
	var/pip_row = 1
	var/pip_column = 1
	var/list/pips = src.pips
	for(var/atom/movable/screen/storage_pip/pip as anything in pips)
		pip.screen_loc = offset_to_screen_loc(pip_start_pixel_x + (pip_column - 1) * (PIP_WIDTH + PIP_X_SPACING), pip_start_pixel_y + (pip_row - 1) * (PIP_HEIGHT + PIP_Y_SPACING))
		pip_column += 1
		if(pip_column > pips_per_row)
			pip_column = 1
			pip_row += 1

/datum/storage_interface/proc/fill_pips(pip_target)
	if(pip_target == cached_pip_target)
		return
	var/pips_active
	if(pip_target > cached_pip_target)
		pips_active = TRUE
	else
		pips_active = FALSE

	var/list/pips = src.pips
	pip_target = min(pip_target, length(pips))
	cached_pip_target = min(cached_pip_target, length(pips))
	for(var/i in min(pip_target, cached_pip_target) + 1 to max(pip_target, cached_pip_target))
		var/atom/movable/screen/storage_pip/update = pips[i]
		update.set_active(pips_active)
	cached_pip_target = pip_target

/datum/storage_interface/proc/highlight_pips(min_highlighted_pip, max_highlighted_pip)
	if(cached_min_highlighted_pip == min_highlighted_pip && cached_max_highlighted_pip == max_highlighted_pip)
		return
	// First, if we had anything, turn em off
	if(cached_min_highlighted_pip && cached_max_highlighted_pip)
		for(var/i in cached_min_highlighted_pip to cached_max_highlighted_pip)
			var/atom/movable/screen/storage_pip/update = pips[i]
			update.set_highlighted(FALSE)
	// then, if we have anything new turn it on
	if(min_highlighted_pip && max_highlighted_pip)
		for(var/i in min_highlighted_pip to max_highlighted_pip)
			var/atom/movable/screen/storage_pip/update = pips[i]
			update.set_highlighted(TRUE)
	cached_min_highlighted_pip = min_highlighted_pip
	cached_max_highlighted_pip = max_highlighted_pip

/datum/storage_interface/proc/set_displaying_weight(obj/item/displaying_weight)
	var/datum/weakref/weight_ref = WEAKREF(displaying_weight)
	if(src.weight_ref == weight_ref)
		return
	src.weight_ref = weight_ref
	update_weight_display()

/datum/storage_interface/proc/update_weight_display()
	var/obj/item/focused_item = weight_ref?.resolve()
	if(!focused_item || focused_item.loc != parent_storage.real_location)
		weight_ref = null
		highlight_pips(0, 0)
		return
	var/start_position = parent_storage.get_weight_before(focused_item) + 1
	highlight_pips(start_position, start_position + focused_item.w_class - 1)

/datum/storage_interface/proc/hide_pips()
	if(cached_pips_hidden == TRUE)
		return
	cached_pips_hidden = TRUE
	// Invalidate cache
	cached_pips_per_row = 0
	cached_pip_start_pixel_x = -1
	cached_pip_start_pixel_y = -1
	cached_pip_count = 0
	var/list/pips = src.pips
	for(var/atom/movable/screen/storage_pip/pip as anything in pips)
		pip.screen_loc = ""

// I don't want to do 2 measuretext calls
GLOBAL_VAR_INIT(weight_average_char_size, 6)
/datum/storage_interface/proc/draw_weight_text(text_stored_weight, text_max_weight, text_start_pixel_x, text_end_pixel_y)
	// No reason to cache here, it'd be constantly invalidated and the work is cheap
	var/stored_text = "[text_stored_weight]"
	var/max_text = "[text_max_weight]"
	// Goal is to center on the /
	var/stored_length = length_char(stored_text) * GLOB.weight_average_char_size
	weight_maptext.maptext = "[stored_text]/[max_text]"
	weight_maptext.maptext_width = length_char(weight_maptext.maptext) * GLOB.weight_average_char_size
	weight_maptext.screen_loc = offset_to_screen_loc(text_start_pixel_x - stored_length, text_end_pixel_y)

GLOBAL_VAR_INIT(pip_height_offset, 30)
// Important to align our center properly
GLOBAL_VAR_INIT(pip_width_offset, -2)
GLOBAL_VAR_INIT(weight_text_height_offset, 28)
// Important to align our center properly
GLOBAL_VAR_INIT(weight_text_width_offset, 0)
/// Updates position of all UI elements
/datum/storage_interface/proc/update_position(screen_start_x, screen_pixel_x, screen_start_y, screen_pixel_y, columns, rows, hidden_cells, screen_max_columns)
	var/start_pixel_x = screen_start_x * 32 + screen_pixel_x
	var/start_pixel_y = screen_start_y * 32 + screen_pixel_y
	var/end_pixel_x = start_pixel_x + (columns - 1) * 32
	var/end_pixel_y = start_pixel_y + (rows - 1) * 32

	cells_full.alpha = 255
	cells_remainder.alpha = 255
	cells_untouchable.alpha = 255

	var/total_cells = columns * rows
	var/max_touchable_cells = parent_storage.max_slots - hidden_cells
	if(total_cells > max_touchable_cells)
		// draw cells_full for the full rectangle of valid cells
		var/end_pixel_y_square = max(end_pixel_y - 32, start_pixel_y)
		var/start_pixel_y_remainder
		if(rows > 1)
			cells_full.screen_loc = spanning_screen_loc(start_pixel_x, start_pixel_y, end_pixel_x, end_pixel_y_square)
			start_pixel_y_remainder = end_pixel_y_square + 32
		else
			cells_full.alpha = 0
			start_pixel_y_remainder = start_pixel_y

		// draw cells_remainder for the last row of partially valid cells
		var/remainder_cells_to_draw = columns - (total_cells - max_touchable_cells)
		var/end_pixel_x_touchable_cells = start_pixel_x + 32 * (remainder_cells_to_draw - 1)
		cells_remainder.screen_loc = spanning_screen_loc(start_pixel_x, start_pixel_y_remainder, end_pixel_x_touchable_cells, end_pixel_y)

		// draw cells_untouchable for the last little bit of that, yeah?
		cells_untouchable.screen_loc = spanning_screen_loc(end_pixel_x_touchable_cells + 32, start_pixel_y_remainder, end_pixel_x, end_pixel_y)
	else
		cells_full.screen_loc = spanning_screen_loc(start_pixel_x, start_pixel_y, end_pixel_x, end_pixel_y)
		cells_remainder.alpha = 0
		cells_untouchable.alpha = 0

	var/left_edge_loc = spanning_screen_loc(min(start_pixel_x + 32, end_pixel_x), start_pixel_y, end_pixel_x, end_pixel_y)
	var/right_edge_loc = spanning_screen_loc(start_pixel_x, start_pixel_y, max(start_pixel_x, end_pixel_x - 32), end_pixel_y)
	corner_top_left.screen_loc = left_edge_loc
	corner_bottom_left.screen_loc = left_edge_loc
	corner_top_right.screen_loc = right_edge_loc
	corner_bottom_right.screen_loc = right_edge_loc

	var/row_left_loc = spanning_screen_loc(start_pixel_x, start_pixel_y + 27, start_pixel_x, start_pixel_y + 27 + max(0, rows - 2) * 32)
	rowjoin_left.screen_loc = row_left_loc
	rowjoin_left.alpha = (rows > 1) * 255

	var/row_right_loc = spanning_screen_loc(end_pixel_x, start_pixel_y + 27, end_pixel_x, start_pixel_y + 27 + max(0, rows - 2) * 32)
	rowjoin_right.screen_loc = row_right_loc
	rowjoin_right.alpha = (rows > 1) * 255

	closer.screen_loc = "[screen_start_x + columns]:[screen_pixel_x - 5],[screen_start_y]:[screen_pixel_y]"

	build_pips()
	// We want to center things in the middle of the field, so like, find that
	var/storage_width = (end_pixel_x + 32) - start_pixel_x
	var/storage_mid_offset = storage_width / 2

	var/stored_weight = parent_storage.get_total_weight()
	var/pip_count = length(pips)
	if(stored_weight > pip_count)
		hide_pips()
		draw_weight_text(stored_weight,
			parent_storage.max_total_storage,
			start_pixel_x + storage_mid_offset + GLOB.weight_text_width_offset,
			end_pixel_y + GLOB.weight_text_height_offset)
		return
	weight_maptext.screen_loc = ""

	var/pips_per_row = FLOOR(screen_max_columns * 32 / (PIP_WIDTH + PIP_X_SPACING), 1)
	var/pips_width = (min(pip_count, pips_per_row) - 1) * (PIP_WIDTH + PIP_X_SPACING)
	position_pips(pips_per_row, start_pixel_x + (storage_mid_offset - pips_width / 2) + GLOB.pip_width_offset, end_pixel_y + GLOB.pip_height_offset, pip_count)
	fill_pips(stored_weight)
	update_weight_display()

#undef MAX_DISPLAYABLE_PIPS
