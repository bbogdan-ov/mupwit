package mupwit

import "lib:cairo"
import "lib:ui"

ASSETS_PATH :: "../assets/"
IMAGES_PATH :: ASSETS_PATH + "images/"
FONTS_PATH :: ASSETS_PATH + "fonts/"

assets_load :: proc(state: ^State) -> (ok: bool) {
	crop_from :: cairo.surface_create_for_rectangle

	// Load fonts.
	state.font_kapli = _load_ttf("kaplimono_regular") or_return

	// Load images
	state.icons.sheet = _load_image("icons", IMAGE_ICONS_SIZE)

	// Crop icons from the sheet.
	target := state.icons.sheet
	for icon, i in Icon {
		surface := crop_from(target, f64(i * ICON_SIZE), 0, ICON_SIZE, ICON_SIZE)
		state.icons.sprites[icon] = surface
	}

	return true
}

assets_destroy :: proc(state: ^State) {
	ui.font_destroy(state.font_kapli)
	ui.sprites_destroy(state.icons)
}

_load_ttf :: proc($name: string) -> (font: ui.Font, ok: bool) {
	data := #load(FONTS_PATH + name + ".ttf")
	return ui.font_load_from_bytes(data)
}

_load_image :: #force_inline proc($name: cstring, $size: [2]i32) -> ^cairo.surface_t {
	data := #load(IMAGES_PATH + name + ".argb32")
	when ODIN_DEBUG do assert(i32(len(data)) == size.x * size.y * ui.PIXEL_CHANNELS)
	return _load_image_from_data(data, size.x, size.y, .ARGB32)
}

_load_image_from_data :: proc(
	data: []u8,
	width, height: i32,
	format: cairo.format_t,
) -> ^cairo.surface_t {
	stride := cairo.format_stride_for_width(format, width)
	return cairo.image_surface_create_for_data(raw_data(data), format, width, height, stride)
}
