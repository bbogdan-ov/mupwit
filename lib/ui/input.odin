package ui

import win "lib:my_window"

is_mouse_down :: proc(button: win.Button) -> bool {
	return button in state.mouse_pressed_buttons && state.mouse_down
}
is_mouse_pressed :: proc(button: win.Button) -> bool {
	return button in state.mouse_pressed_buttons && state.mouse_pressed
}
is_mouse_released :: proc(button: win.Button) -> bool {
	return button in state.mouse_released_buttons
}

is_pointer_inside :: proc(rect: Rect) -> bool {
	return overlap(state.pointer, rect)
}
is_hovering :: proc(rect: Rect) -> bool {
	return state.dragging == nil && is_pointer_inside(rect)
}

rel_pointer :: proc(box: Box) -> Vec2 {
	pos := state.pointer - rect_pos(box)
	pos.y += i32(box.scroll)
	return pos
}
