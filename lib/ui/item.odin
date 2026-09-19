package ui

import "base:intrinsics"

Item_Index :: i32

// Reorderable item.
Item :: struct {
	tween:       Tween(f32),
	position:    i32,
	is_hovering: bool,
}

// List of reorderable items.
Item_List :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Item) {
	items:          [dynamic]T,
	item_height:    i32,
	hovering:       Maybe(Item_Index),
	reordering:     Maybe(Item_Index),
	_cur_reorder:   Item_Reorder,
	just_reordered: bool,
	reorder:        Item_Reorder,
}

Item_Reorder :: struct {
	from, to: Item_Index,
}

item_list_update :: proc(box: Box, list: ^Item_List($T), dt: Seconds) {
	UPDATE_SCROLLOFF :: 8

	assert(list.item_height > 0)

	list.hovering = nil
	list.just_reordered = false

	from, to := item_list_visible_range(box, list)
	from = max(from - UPDATE_SCROLLOFF, 0)
	to = min(to + UPDATE_SCROLLOFF, len(list.items))

	for i in from ..< to {
		index := Item_Index(i)
		item := &list.items[i]
		if index != list.reordering {
			item_update(box, list, item, index, dt)
		}
	}

	reordering, has_reordering := list.reordering.?
	if has_reordering {
		// Update the currently reordering item separately from others so it
		// updates no matter if it within the view or not.
		item := &list.items[reordering]
		item_update(box, list, item, reordering, dt)

		// Order changed.
		if list._cur_reorder.from != list._cur_reorder.to {
			_item_list_reorder(list, list._cur_reorder)
			list.reorder.to = list._cur_reorder.to
			list._cur_reorder = {}
		}
	}
}

_item_list_reorder :: proc(list: ^Item_List($T), reorder: Item_Reorder) {
	item := list.items[reorder.from]

	start, end := slice_reorder(list.items[:], int(reorder.from), int(reorder.to))

	list.items[reorder.to] = item
	// Update dragging ID because currently reordering item's address changed
	// after reordering.
	state.dragging = Element_ID(&list.items[reorder.to])

	// Update and animate positions of the items that were moved.
	for &other, i in list.items[start:end] {
		index := Item_Index(start + i)
		_item_tween_to_rest(&other, index, list.item_height)
	}
}

item_update :: proc(box: Box, list: ^Item_List($T), item: ^Item, index: Item_Index, dt: Seconds) {
	id := Element_ID(item)

	tween_update(&item.tween, dt)

	rect := item_rect(box, item.position, list.item_height)

	switch state.can_drag {
	case id:
		item.is_hovering = true
	case nil:
		if state.dragging != nil do break

		py := rel_pointer(box).y / list.item_height
		item.is_hovering = is_pointer_inside(box) && py == index
	}

	switch {
	case state.just_started_dragging == id:
		_item_start_pos_tween(item)
		list.reordering = index
		list.reorder = {index, index}

	case state.just_stopped_dragging == id:
		_item_tween_to_rest(item, index, list.item_height)
		list.reordering = nil
		list.just_reordered = list.reorder.from != list.reorder.to

	case state.dragging == id:
		item.position = rel_pointer(box).y + state.drag_offset.y
		_item_update_index(list, item, index)

	case item.is_hovering && is_mouse_pressed(.Left):
		set_can_drag(id, {0, rect.y - state.press_pos.y})
		list.reordering = index
	}

	if item.is_hovering {
		list.hovering = index
	}
}

_item_update_index :: proc(list: ^Item_List($T), item: ^Item, index: Item_Index) {
	center := item.position + list.item_height / 2
	new_index := center / list.item_height
	new_index = clamp(new_index, 0, Item_Index(len(list.items) - 1))
	if index != new_index {
		list._cur_reorder = {index, new_index}
		list.reordering = new_index
	}
}

item_rect :: proc(box: Box, position: i32, height: i32) -> Rect {
	rect := box.rect
	rect.y += position - i32(box.scroll)
	rect.height = height
	return rect
}

item_tweened_pos :: proc(item: ^Item) -> i32 {
	return i32(tween_sine_out(&item.tween, f32(item.position)))
}

item_list_visible_range :: proc(box: Box, list: ^Item_List($T)) -> (from, to: int) {
	from, to = scroll_visible_range(box, len(list.items), list.item_height)
	return
}

_item_tween_to_rest :: proc(item: ^Item, index: Item_Index, height: i32) {
	_item_start_pos_tween(item)
	item.position = index * height
}
_item_start_pos_tween :: proc(item: ^Item) {
	tween_play(&item.tween, f32(item.position), 0.2)
}
