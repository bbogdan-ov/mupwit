package ui

Context :: struct #all_or_none {
	text_trunc_x:     f32,
	text_trunc_width: f32,
}

ctx: Context

// Reset UI context to defaults.
ctx_reset :: proc() {
	ctx = Context {
		text_trunc_x     = 0,
		text_trunc_width = 0,
	}
}
