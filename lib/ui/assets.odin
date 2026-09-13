package ui

import "lib:cairo"
import win "lib:my_window"

Font :: struct {
	using face: ^cairo.font_face_t,
	ft:         win.Font_Face,
}

Sprites :: struct($T: typeid) {
	sprites: [T]^cairo.surface_t,
	sheet:   ^cairo.surface_t,
}

font_load_from_bytes :: proc(data: []u8) -> (font: Font, ok: bool) {
	win.font_face_load(state.font_library, &font.ft, raw_data(data), u32(len(data)), 0) or_return
	font.face = cairo.ft_font_face_create_for_ft_face(font.ft, 0)
	return font, true
}

font_destroy :: proc(font: Font) {
	cairo.font_face_destroy(font.face)
	win.font_face_destroy(font.ft)
}

sprites_destroy :: proc(sprites: Sprites($T)) {
	for surface in sprites.sprites do cairo.surface_destroy(surface)
	cairo.surface_destroy(sprites.sheet)
}
