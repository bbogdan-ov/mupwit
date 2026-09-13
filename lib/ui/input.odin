package ui

import win "lib:my_window"

is_mouse_down :: proc(button: win.Button) -> bool {
	return button in state.mouse_pressed_buttons && state.mouse_down
}
is_mouse_pressed :: proc(button: win.Button) -> bool {
	return button in state.mouse_pressed_buttons && state.mouse_pressed
}
is_mouse_released :: proc(button: win.Button) -> bool {
	return button in state.mouse_released_buttons && state.mouse_relesed
}
