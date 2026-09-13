package ui

import win "lib:my_window"

PIXEL_CHANNELS :: 4

state: struct {
	dragging:           Maybe(Element_ID),
	drag_scroll_offset: f32,

	// Input.
	pointer:            Vec2,
	prev_pointer:       Vec2,
	press_pos:          Vec2,
	buttons:            bit_set[win.Button;u8],
	button_down:        bool,
	button_pressed:     bool,

	// Assets.
	font_library:       win.Font_Library,
}

init :: proc() {
	ok := win.font_library_init(&state.font_library)
	assert(ok) // TODO: handle error.
}

destroy :: proc() {
	win.font_library_destroy(state.font_library)
}

update :: proc() {
	state.button_pressed = false
	state.prev_pointer = state.pointer
}

on_pointer_button :: proc "contextless" (button: win.Button, button_state: win.Button_State) {
	switch button_state {
	case .Released:
		state.buttons -= {button}
		state.button_down = false
	case .Pressed:
		state.buttons += {button}
		state.button_down = true
		state.button_pressed = true
		state.press_pos = state.pointer
	}
}

on_pointer_motion :: proc "contextless" (pos: Vec2) {
	state.pointer = pos
}
