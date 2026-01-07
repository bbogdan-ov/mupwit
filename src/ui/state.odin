package ui

import "base:runtime"
import "core:strings"

State :: struct #all_or_none {
	frame_arena:     runtime.Arena,
	frame_allocator: runtime.Allocator,
}

state: State

state_init :: proc() {
	state = State {
		frame_arena     = runtime.Arena{},
		frame_allocator = runtime.Allocator{},
	}

	state.frame_allocator = runtime.arena_allocator(&state.frame_arena)
}

state_frame_begin :: proc() {
	free_all(state.frame_allocator)
}

state_destroy :: proc() {}

frame_cstring :: proc(s: string, loc := #caller_location) -> cstring {
	return strings.clone_to_cstring(s, state.frame_allocator, loc)
}
