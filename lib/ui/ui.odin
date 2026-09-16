package ui

import win "lib:my_window"

PIXEL_CHANNELS :: 4

State :: struct {
	view:                   Rect,
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
	cursor:                 win.Cursor,

	// Assets.
	font_library:           win.Font_Library,
}

state: State

init :: proc() {
	ok := win.font_library_init(&state.font_library)
	assert(ok) // TODO: handle error.
}

destroy :: proc() {
	win.font_library_destroy(state.font_library)
}

update :: proc() {
	state.mouse_pressed = false
	state.prev_pointer = state.pointer
	state.mouse_released_buttons = {}
	state.cursor = .Default
}

set_cursor :: proc(cursor: win.Cursor) {
	state.cursor = cursor
}

on_pointer_button :: proc "contextless" (button: win.Button, button_state: win.Button_State) {
	switch button_state {
	case .Released:
		state.mouse_pressed_buttons -= {button}
		state.mouse_released_buttons += {button}
		state.mouse_down = false
	case .Pressed:
		state.mouse_pressed_buttons += {button}
		state.mouse_down = true
		state.mouse_pressed = true
		state.press_pos = state.pointer
	}
}

on_pointer_motion :: proc "contextless" (pos: Vec2) {
	state.pointer = pos
}
