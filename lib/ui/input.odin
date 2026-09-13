package ui

import win "lib:my_window"

is_button_down :: proc(button: win.Button) -> bool {
	return button in state.buttons && state.button_down
}
is_button_pressed :: proc(button: win.Button) -> bool {
	return button in state.buttons && state.button_pressed
}
