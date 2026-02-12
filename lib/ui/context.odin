package ui

Context :: struct #all_or_none {
	// Width of the current container.
	width:  f32,
	// Height of the current container.
	height: f32,

	// Scroll of the current container.
	scroll: f32,
}

ctx: Context

// Reset UI context to defaults.
ctx_reset :: proc() {
	ctx = Context {
		width  = 0,
		height = 0,
		scroll = 0,
	}
}
