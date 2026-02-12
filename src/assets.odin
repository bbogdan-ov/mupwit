package mupwit

import files "../build/assets"
import "../lib/ui"

Assets :: struct #all_or_none {
	normal_font:   ui.Font,
	italic_font:   ui.Font,
	boxes:         ui.Texture,
	icons:         ui.Texture,
	dummy_artwork: ui.Texture,
}

assets: Assets

load_assets :: proc() {
	assert(ui.window.ready)

	font := files.font_load_kaplimono_regular()

	assets = Assets {
		normal_font   = font,
		italic_font   = font,
		boxes         = files.image_load_boxes(),
		icons         = files.image_load_icons(),
		dummy_artwork = files.image_load_dummy_artwork(),
	}
}

assets_destroy :: proc() {
	ui.unload_font(assets.normal_font)
	ui.unload_font(assets.italic_font)
	ui.unload_texture(assets.boxes)
	ui.unload_texture(assets.icons)
	ui.unload_texture(assets.dummy_artwork)
}
