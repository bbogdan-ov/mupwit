//
// Small and simple half-retained-mode software-rendering GUI library that uses
// Cairo for drawing.
//
// What i mean by "half-retained-mode" is that you should manually store
// interactible elements (buttons, sliders, etc) somewhere and they also depend
// on their own state from a previous frame. For example before checking
// whether a button is being pressed you must draw it at least once so it can
// know its dimensions. This approach has an obvious downside - you can't know
// dimensions (position and size) of an elements until it is drawn at least
// once. But it is also a simpler approach than traditional retained-mode GUI
// and more flexible than traditional immediate-mode GUI.
//
// All layout calculations are done manually, but may be i should make a simple
// layout library like Clay?..
//

package ui

import win "lib:my_window"

PIXEL_CHANNELS :: 4

DIRTY_INVERVAL :: Seconds(2)

ELEMENT_ID_NONE :: Element_ID(0)

// Unique ID of an element. Most elements just use their pointers as their IDs.
Element_ID :: distinct uintptr

Controls :: enum {
	Any = 0,
	Keyboard,
	Mouse,
}

State :: struct {
	view:                   Rect,
	// When `true`, indicates that the screen should be redrawn.
	dirty:                  bool,
	dirty_timer:            Seconds,

	// Currently dragged element.
	dragging:               Maybe(Element_ID),
	defer_stop_dragging:    bool,
	just_started_dragging:  Element_ID,
	just_stopped_dragging:  Element_ID,
	// Offset of the currently dragged element relative to the mouse pointer.
	drag_offset:            Vec2,
	drag_scroll_offset:     f32,

	// Input.
	_controls:              Controls,
	pointer:                Vec2,
	prev_pointer:           Vec2,
	press_pos:              Vec2,
	mouse_pressed_buttons:  bit_set[win.Button;u8],
	mouse_released_buttons: bit_set[win.Button;u8],
	mouse_down:             bool,
	mouse_pressed:          bool,
	double_click_timer:     Seconds,
	cursor:                 win.Cursor,

	// Assets.
	font_library:           win.Font_Library,
}

state: State

init :: proc() {
	state.dirty = true

	ok := win.font_library_init(&state.font_library)
	assert(ok) // TODO: handle error.
}

destroy :: proc() {
	win.font_library_destroy(state.font_library)
}

dirty :: proc(flag: bool) {
	state.dirty |= flag
}
// Updates a value and if it has been changed, sets the `dirty` flag.
dirty_set :: proc(current: ^$T, updated: T) {
	if current^ != updated {
		current^ = updated
		dirty(true)
	}
}

update :: proc(dt: Seconds) {
	if state.dirty_timer > 0 {
		state.dirty_timer -= dt
	}
	if state.dirty_timer <= 0 {
		state.dirty_timer = DIRTY_INVERVAL
		dirty(true)
	}

	if state.double_click_timer > 0 {
		state.double_click_timer -= dt
	}
	if state.mouse_pressed {
		state.double_click_timer = DOUBLE_CLICK_DURATION
	}

	if state.defer_stop_dragging {
		state.dragging = nil
		state.defer_stop_dragging = false
	}

	state.just_started_dragging = ELEMENT_ID_NONE
	state.just_stopped_dragging = ELEMENT_ID_NONE
	state.mouse_pressed = false
	state.prev_pointer = state.pointer
	state.mouse_released_buttons = {}
	state.cursor = .Default
}

start_dragging :: proc(id: Element_ID, loc := #caller_location) {
	if state.dragging != nil {
		if ODIN_DEBUG do panic("Cannot start dragging when already dragging something else", loc)
		return
	}
	state.dragging = id
	state.just_started_dragging = id
	dirty(true)
}
stop_dragging :: proc(id: Element_ID, loc := #caller_location) {
	if state.dragging == nil {
		if ODIN_DEBUG do panic("Nothing is being dragged", loc)
		return
	}
	if state.dragging != id {
		if ODIN_DEBUG do panic("Stopped dragging a wrong element", loc)
		return
	}
	state.defer_stop_dragging = true
	state.just_stopped_dragging = id
	dirty(true)
}

set_cursor :: proc(cursor: win.Cursor) {
	state.cursor = cursor
}

set_controls :: proc(controls: Controls) -> (ok: bool) {
	if controls == .Any {
		state._controls = .Any
		return true
	} else if state._controls == .Any {
		state._controls = controls
		return true
	} else {
		return state._controls == controls
	}
}

controls :: proc() -> Controls {
	return state._controls
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
