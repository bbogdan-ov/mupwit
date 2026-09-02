package mupwit

import "lib:cairo"
import win "lib:my_window"

ASSETS_PATH :: "../assets/"
IMAGES_PATH :: ASSETS_PATH + "images/"
FONTS_PATH :: ASSETS_PATH + "fonts/"

Font :: struct {
	using face: ^cairo.font_face_t,
	ft:         win.Font_Face,
}

assets_load :: proc() -> (ok: bool) {
	crop_from :: cairo.surface_create_for_rectangle

	// Load fonts.
	win.font_library_init(&state.font_library) or_return // TODO: handle error.

	state.font_kapli = _load_ttf("kaplimono_regular") or_return

	// Load images
	state.image_icons_sheet = _load_png("icons", 112, 16)

	// Crop icons from the sheet.
	target := state.image_icons_sheet
	for icon, i in Icon {
		surface := crop_from(target, f64(i * ICON_WIDTH), 0, ICON_WIDTH, ICON_HEIGHT)
		state.image_icons[icon] = surface
	}

	return true
}

assert_destroy :: proc() {
	font_destroy(state.font_kapli)
	win.font_library_destroy(state.font_library)

	for surface in state.image_icons do cairo.surface_destroy(surface)
	cairo.surface_destroy(state.image_icons_sheet)
}

font_destroy :: proc(font: Font) {
	cairo.font_face_destroy(font.face)
	win.font_face_destroy(font.ft)
}

_load_ttf :: proc($name: string) -> (font: Font, ok: bool) {
	data := #load(FONTS_PATH + name + ".ttf")
	win.font_face_load(state.font_library, &font.ft, raw_data(data), u32(len(data)), 0) or_return
	font.face = cairo.ft_font_face_create_for_ft_face(font.ft, 0)
	return font, true
}

_load_png :: proc($name: cstring, $width, $height: i32) -> ^cairo.surface_t {
	data := #load(IMAGES_PATH + name + ".argb32")
	assert(i32(len(data)) == width * height * PIXEL_SIZE)
	return _load_image_from_data(data, width, height, .ARGB32)
}

_load_image_from_data :: proc(
	data: []u8,
	width, height: i32,
	format: cairo.format_t,
) -> ^cairo.surface_t {
	stride := cairo.format_stride_for_width(format, width)
	return cairo.image_surface_create_for_data(raw_data(data), format, width, height, stride)
}
