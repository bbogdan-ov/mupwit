package ui

import win "lib:my_window"

PIXEL_CHANNELS :: 4

state: struct {
	dragging:               Maybe(Element_ID),
	drag_scroll_offset:     f32,

	// Input.
	pointer:                Vec2,
	prev_pointer:           Vec2,
	press_pos:              Vec2,
	mouse_pressed_buttons:  bit_set[win.Button;u8],
	mouse_released_buttons: bit_set[win.Button;u8],
	mouse_down:             bool,
	mouse_pressed:          bool,
	mouse_relesed:          bool,

	// Assets.
	font_library:           win.Font_Library,
}

init :: proc() {
	ok := win.font_library_init(&state.font_library)
	assert(ok) // TODO: handle error.
}

destroy :: proc() {
	win.font_library_destroy(state.font_library)
}

update :: proc() {
	state.mouse_pressed = false
	state.mouse_relesed = false
	state.prev_pointer = state.pointer
}

on_pointer_button :: proc "contextless" (button: win.Button, button_state: win.Button_State) {
	switch button_state {
	case .Released:
		state.mouse_pressed_buttons -= {button}
		state.mouse_released_buttons += {button}
		state.mouse_down = false
		state.mouse_relesed = true
	case .Pressed:
		state.mouse_pressed_buttons += {button}
		state.mouse_released_buttons -= {button}
		state.mouse_down = true
		state.mouse_pressed = true
		state.press_pos = state.pointer
	}
}

on_pointer_motion :: proc "contextless" (pos: Vec2) {
	state.pointer = pos
}
