package ui

Scroll :: struct #all_or_none {
	// Vertical offset of the scroll.
	offset: f32,
}

scroll_create :: proc() -> Scroll {
	return Scroll{offset = 0}
}

scroll_update :: proc(scroll: ^Scroll) {
	panic("TODO:")
}
