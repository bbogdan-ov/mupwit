package ui

import win "lib:my_window"

PIXEL_CHANNELS :: 4

DRAG_START_THRESHOLD :: 10
DIRTY_INVERVAL :: Seconds(2)

ELEMENT_ID_NONE :: Element_ID(0)

Element_ID :: distinct uintptr

State :: struct {
	view:                   Rect,
	dirty:                  bool,
	dirty_timer:            Seconds,

	// Currently dragged element.
	dragging:               Maybe(Element_ID),
	just_started_dragging:  Element_ID,
	just_stopped_dragging:  Element_ID,
	// Element was pressed and might be started dragging when user moves
	// mouse with a button held down by some distance.
	can_drag:               Maybe(Element_ID),
	// Offset of the currently dragged element relative to the mouse pointer.
	drag_offset:            Vec2,
	drag_scroll_offset:     f32,

	// Input.
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

	_update_drag()

	if state.double_click_timer > 0 {
		state.double_click_timer -= dt
	}
	if state.mouse_pressed {
		state.double_click_timer = DOUBLE_CLICK_DURATION
	}

	state.mouse_pressed = false
	state.prev_pointer = state.pointer
	state.mouse_released_buttons = {}
	state.cursor = .Default
}

_update_drag :: proc() {
	state.just_started_dragging = ELEMENT_ID_NONE
	state.just_stopped_dragging = ELEMENT_ID_NONE

	dragging, has_dragging := state.dragging.?

	if !has_dragging {
		can_drag, ok := state.can_drag.?
		if is_mouse_down(.Left) && ok {
			diff := state.pointer - state.press_pos
			if abs(diff.x) + abs(diff.y) > DRAG_START_THRESHOLD {
				start_dragging(can_drag)
				state.can_drag = nil
			}
		} else {
			state.can_drag = nil
		}
	} else if is_mouse_released(.Left) {
		stop_dragging(dragging)
	}
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
	state.dragging = nil
	state.just_stopped_dragging = id
	dirty(true)
}
set_can_drag :: proc(id: Element_ID, offset: Vec2) {
	state.can_drag = id
	state.drag_offset = offset
	dirty(true)
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
