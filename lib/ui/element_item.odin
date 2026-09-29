package ui

import "base:intrinsics"

import win "lib:my_window"

Item_Index :: i32

// Reorderable item.
Item :: struct {
	tween:        Tween([2]f32),
	// Position relative to a list box.
	position:     Vec2,
	// Current tweened position.
	cur_position: Vec2,
}

Item_Reorder :: struct {
	from, to: Item_Index,
}

Reorder_State :: enum {
	None = 0,
	Preparing, // Item is held down but not reodering yet.
	Active, // Item is being reordered.
}

// List of reorderable items.
Item_List :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Item) {
	items:                    [dynamic]T,
	item_width:               i32,
	item_height:              i32,
	scroll_padding:           i32,
	columns:                  Item_Index,
	hovering:                 Maybe(Item_Index),
	last_hovered:             Item_Index,
	reordering:               Item_Index,
	reorder_state:            Reorder_State,
	reorder:                  Item_Reorder,
	reorderable:              bool,
	_center_scroll:           bool,

	// Callbacks.
	userdata:                 rawptr,
	item_update:              proc(list: ^Item_List(T), item: ^T, index: Item_Index, dt: Seconds),
	on_item_reordered:        proc(
		list: ^Item_List(T),
		item: ^T,
		index: Item_Index,
		reorder: Item_Reorder,
	),
	on_item_start_reordering: proc(list: ^Item_List(T), item: ^T, index: Item_Index),
	on_item_stop_reordering:  proc(list: ^Item_List(T), item: ^T, index: Item_Index),
}

item_list_init :: proc(list: ^Item_List($T), item_height: i32, allocator := context.allocator) {
	list.items = make([dynamic]T, allocator)
	list.item_width = 1
	list.item_height = item_height
	list.columns = 1
}

item_list_destroy :: proc(list: ^Item_List($T)) {
	delete(list.items)
	list.items = nil
}

item_list_update :: proc(box: ^Box, scroll: ^Scroll, list: ^Item_List($T), dt: Seconds) {
	UPDATE_SCROLLOFF :: 8

	assert(list.item_height > 0)

	if controls() != .Keyboard {
		// NOTE: it is important to start scrolling before updating the `Scroll` so
		// that the reordering item doesn't jitter when moving, because
		// `scroll_update` updates box's scroll and items depend on it.
		scroll_diff := _item_list_should_scroll_by(box^, list)
		scroll_by(scroll, scroll_diff)
	}

	scroll_update(box, scroll, dt)

	_item_list_update_hovering(box^, list)
	_item_list_update_reordering(box^, list)

	from, to := item_list_visible_range(box^, list)
	from = max(from - UPDATE_SCROLLOFF, 0)
	to = min(to + UPDATE_SCROLLOFF, items_count(list))

	for i in from ..< to {
		index := Item_Index(i)
		item := &list.items[i]
		if !item_is_reodering(list, index) {
			item_update(box^, list, item, index, dt)
		}
	}

	if list.reorder_state != .None {
		// Update the currently reordering item separately from others so it
		// updates no matter if it within the view or not.
		item := &list.items[list.reordering]
		item_update(box^, list, item, list.reordering, dt)

		if controls() == .Keyboard {
			item_list_scroll_to(
				box^,
				scroll,
				list,
				list.reordering,
				center = list._center_scroll,
				smooth = false,
			)
		}
	}

	if controls() != .Keyboard {
		if list.reorder_state == .Active {
			set_cursor(.Grabbing)
		} else if list.hovering != nil {
			set_cursor(.Pointer)
		}
	}
}

item_list_set_cursor :: proc(box: Box, scroll: ^Scroll, list: ^Item_List($T), cursor: Vec2) {
	index := item_cursor_to_index(cursor, list.columns)
	index = clamp(index, 0, items_count(list) - 1)

	if controls() == .Mouse {
		item_list_scroll_to(box, scroll, list, index, list._center_scroll)
		return
	}

	if list.reorder_state == .Active {
		if list.reordering == index do return

		item := &list.items[list.reordering]

		item_tween_to_rest(item, index, list.item_height)
		_item_reorder(list, index)
	} else if list.hovering != index {
		item_list_set_hovering(list, index)
		item_list_scroll_to(box, scroll, list, index, list._center_scroll)
	}
}

_item_list_update_reordering :: proc(box: Box, list: ^Item_List($T)) {
	REORDER_START_THRESHOLD :: 10

	if !list.reorderable do return
	if controls() == .Keyboard do return

	hovering, has_hovering := list.hovering.?

	switch {
	case list.reorder_state == .Active:
		if !is_mouse_down(.Left) {
			item_list_stop_reordering(list)
			set_controls(.Any)
			break
		}

		pos := rel_pointer(box).y - state.drag_offset.y
		item := &list.items[list.reordering]
		dirty_set(&item.position.y, pos)

		// Reorder item to its new position if changed.
		_item_reorder_to_its_pos(list, list.reordering)

	case list.reorder_state == .Preparing:
		if !is_mouse_down(.Left) {
			list.reorder_state = .None
			set_controls(.Any)
			break
		}

		item := &list.items[list.reordering]
		pos := item_view(box, item.position)
		diff := state.pointer.y - (pos.y + state.drag_offset.y)
		if abs(diff) > REORDER_START_THRESHOLD {
			item_list_start_reordering(list, hovering)
		}

	case has_hovering && is_mouse_pressed(.Left):
		set_controls(.Mouse) or_break

		item := &list.items[hovering]
		pos := item_view(box, item.position)

		state.drag_offset = {0, state.pointer.y - pos.y}
		list.reordering = hovering
		list.reorder_state = .Preparing
	}
}

_item_list_update_hovering :: proc(box: Box, list: ^Item_List($T)) {
	if controls() == .Keyboard {
		hovering, has_hovering := list.hovering.?
		if has_hovering {
			list.hovering = clamp(hovering, 0, items_count(list) - 1)
		}
		return
	}

	hovering: Maybe(Item_Index) = nil

	if list.reorder_state != .None {
		hovering = list.reordering
	} else if is_hovering(box) {
		pointer := rel_pointer(box)
		index := pointer.y / list.item_height * list.columns
		if list.columns > 1 {
			index += pointer.x / list.item_width
		}

		if within(index, 0, i32(len(list.items))) {
			hovering = index
		}
	}

	item_list_set_hovering(list, hovering)
}

item_list_set_hovering :: proc(list: ^Item_List($T), index: Maybe(Item_Index)) {
	if list.reorder_state == .Active do return

	count := items_count(list)
	if count == 0 {
		list.hovering = nil
	} else if index, ok := index.?; ok {
		index = clamp(index, 0, count - 1)
		list.last_hovered = index
		dirty_set(&list.hovering, index)
	} else {
		dirty_set(&list.hovering, nil)
	}
}

item_list_start_reordering :: proc(list: ^Item_List($T), index: Item_Index) {
	if !list.reorderable do return
	if list.reorder_state == .Active do return

	assert(list.columns == 1, "TODO: reordering for multi-column lists is not implemented yet")

	item := &list.items[index]
	_item_start_pos_tween(item)

	list.hovering = index
	list.reorder = {index, index}
	list.reordering = index
	list.reorder_state = .Active
	start_dragging(Element_ID(list))

	if list.on_item_start_reordering != nil {
		list.on_item_start_reordering(list, item, index)
	}

	dirty(true)
}

// Move currently reordering item to the position it is currently in and stop reordering.
item_list_stop_reordering :: proc(list: ^Item_List($T)) {
	if list.reorder_state != .Active do return

	_item_reorder_to_its_pos(list, list.reordering)
	item_list_cancel_reordering(list)

	if list.on_item_reordered != nil && list.reorder.from != list.reorder.to {
		index := list.reorder.to
		item := &list.items[index]
		list.on_item_reordered(list, item, index, list.reorder)
	}
}

// Move currently reordering item to its original position and stop reordering.
item_list_cancel_reordering :: proc(list: ^Item_List($T)) {
	if list.reorder_state != .Active do return

	item := &list.items[list.reordering]
	item_tween_to_rest(item, list.reordering, list.item_height)

	if list.on_item_stop_reordering != nil {
		list.on_item_stop_reordering(list, item, list.reordering)
	}

	list.reorder_state = .None
	list.reordering = -1
	stop_dragging(Element_ID(list))

	dirty(true)
}

_item_reorder_to_its_pos :: proc(list: ^Item_List($T), from: Item_Index) -> (to: Item_Index) {
	item := &list.items[from]
	to = _item_index_from_pos(item.position, list.item_height, items_count(list))
	_item_reorder(list, to)
	return to
}

_item_reorder :: proc(list: ^Item_List($T), to: Item_Index) {
	assert(list.reorder_state == .Active)

	if len(list.items) == 0 do return
	if list.reordering == to do return

	start, end := slice_reorder(list.items[:], int(list.reordering), int(to))

	// Update indices because this item's index changed after reordering.
	list.hovering = to
	list.reordering = to
	list.reorder.to = to

	// Update and animate positions of the items that were shifted with in the array.
	for index in start ..< end {
		item := &list.items[index]
		item_tween_to_rest(item, Item_Index(index), list.item_height)
	}

	dirty(true)
}

item_list_scroll_to :: proc(
	box: Box,
	scroll: ^Scroll,
	list: ^Item_List($T),
	index: Item_Index,
	center := false,
	smooth := true,
) {
	item := &list.items[index]
	y := item.cur_position.y

	height := list.item_height
	rel := y - i32(box.scroll)

	off: i32
	switch {
	case center:
		off = y + height / 2 - box.height / 2
	case rel < list.scroll_padding:
		off = y - list.scroll_padding
	case rel > box.height - height - list.scroll_padding:
		off = y - box.height + height + list.scroll_padding
	case:
		return
	}

	scroll_to(box, scroll, f32(off), smooth = smooth)
}

_item_list_should_scroll_by :: proc(box: Box, list: ^Item_List($T)) -> f32 {
	if list.reorder_state != .Active do return 0

	item := &list.items[list.reordering]

	pos: i32 = item.position.y + list.item_height / 2 - box.y - i32(box.scroll)
	top: i32 = ITEM_REORDER_SCROLLOFF
	bottom: i32 = box.height - ITEM_REORDER_SCROLLOFF
	if pos < top {
		return f32(pos - top) * ITEM_REORDER_SCROLL_MUL
	} else if pos > bottom {
		return f32(pos - bottom) * ITEM_REORDER_SCROLL_MUL
	} else {
		return 0
	}
}

item_list_on_keyboard_key :: proc(
	box: Box,
	scroll: ^Scroll,
	list: ^Item_List($T),
	ev: win.Key_Event,
) -> (
	propagate: bool,
) {
	is_key :: win.is_key
	is_ctrl_key :: win.is_ctrl_key
	is_shift_key :: win.is_shift_key

	page_jump := max(box.height / list.item_height, 3)
	jump := max(page_jump / 2, 2)

	rows := item_list_rows(list)
	hovering := list.hovering.? or_else list.last_hovered
	cursor := item_cursor_from_index(hovering, list.columns)
	list._center_scroll = false

	is_reordering := list.reorder_state == .Active
	
	// odinfmt:disable
	switch {
	case is_reordering && is_key(ev, .R): fallthrough
	case is_reordering && is_key(ev, .Enter): fallthrough
	case is_reordering && is_key(ev, .Esc):
		set_controls(.Keyboard) or_break
		item_list_stop_reordering(list)

	case is_key(ev, .J), is_key(ev, .Down):  cursor.y += 1
	case is_key(ev, .K), is_key(ev, .Up):    cursor.y -= 1
	case is_key(ev, .H), is_key(ev, .Left):  cursor.x -= 1
	case is_key(ev, .L), is_key(ev, .Right): cursor.x += 1

	case is_ctrl_key(ev, .D): cursor.y += jump
	case is_ctrl_key(ev, .U): cursor.y -= jump

	case is_ctrl_key(ev, .F), is_key(ev, .Page_Down): cursor.y += page_jump
	case is_ctrl_key(ev, .B), is_key(ev, .Page_Up):   cursor.y -= page_jump

	case is_key(ev, .G), is_key(ev, .Home):
		cursor.y = 0
	case is_shift_key(ev, .G), is_key(ev, .End):
		cursor.y = rows - 1
	case is_shift_key(ev, .M):
		cursor.y = rows / 2
		list._center_scroll = true

	case is_key(ev, .R):
		set_controls(.Keyboard) or_break
		index := item_cursor_to_index(cursor, list.columns)
		item_list_start_reordering(list, index)

	case:
		return true
	}
	// odinfmt:enable

	set_controls(.Keyboard)
	item_list_set_cursor(box, scroll, list, cursor)

	return false
}

item_make :: proc(list: ^Item_List($T), index: Item_Index) -> Item {
	pos: Vec2
	pos.x = index % list.columns * list.item_width
	pos.y = index / list.columns * list.item_height
	return Item{position = pos, cur_position = pos}
}

item_update :: proc(box: Box, list: ^Item_List($T), item: ^T, index: Item_Index, dt: Seconds) {
	// TODO: finish tween if item is outside of the view.
	tween_update(&item.tween, dt)

	pos := tween_ease(&item.tween, cast([2]f32)item.position, .Sine_Out)
	item.cur_position = cast(Vec2)pos

	if list.item_update != nil {
		list.item_update(list, item, index, dt)
	}
}

item_is_reodering :: #force_inline proc "contextless" (
	list: ^Item_List($T),
	index: Item_Index,
) -> bool {
	return list.reorder_state != .None && list.reordering == index
}

_item_index_from_pos :: proc(position: Vec2, height: i32, count: Item_Index) -> Item_Index {
	pos := position.y + height / 2
	index := Item_Index(pos / height)
	return clamp(index, 0, count - 1)
}

// Returns item position relative to the view.
item_view :: proc(box: Box, position: Vec2) -> Vec2 {
	return position + rect_pos(box) - Vec2{0, i32(box.scroll)}
}

item_list_visible_range :: proc(box: Box, list: ^Item_List($T)) -> (from, to: Item_Index) {
	rows := item_list_rows(list)
	from, to = scroll_visible_range(box, rows, list.item_height)
	from *= list.columns
	to = min(to * list.columns, items_count(list))
	return from, to
}

items_count :: proc(list: ^Item_List($T)) -> Item_Index {
	return Item_Index(len(list.items))
}

item_list_rows :: proc(list: ^Item_List($T)) -> Item_Index {
	count := items_count(list) / list.columns
	count += items_count(list) % list.columns
	return count
}

item_list_content_height :: proc(list: ^Item_List($T)) -> i32 {
	return item_list_rows(list) * list.item_height
}

item_cursor_from_index :: proc(index, columns: Item_Index) -> Vec2 {
	return {index % columns, index / columns}
}
item_cursor_to_index :: proc(cursor: Vec2, columns: Item_Index) -> Item_Index {
	return cursor.x + cursor.y * columns
}

item_within_box :: proc(box: Box, y: i32, height: i32) -> bool {
	y := y - box.y - i32(box.scroll)
	return -height < y && y < box.height
}
item_within_view :: proc(box: Box, y: i32, height: i32) -> bool {
	y := y - box.y - i32(box.scroll)
	return -height * 2 < y && y < state.view.height + height
}

item_tween_to_rest :: proc(item: ^Item, index: Item_Index, height: i32) {
	_item_start_pos_tween(item)
	item.position.y = index * height
}
_item_start_pos_tween :: proc(item: ^Item) {
	tween_play(&item.tween, cast([2]f32)item.cur_position, ITEM_ANIM_DURATION)
}
