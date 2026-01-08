package ui

import rl "vendor:raylib"

import raw "../../build/assets"

Assets :: struct #all_or_none {
	normal_font:   rl.Font,
	italic_font:   rl.Font,
	boxes:         rl.Texture,
	icons:         rl.Texture,
	dummy_artwork: rl.Texture,
}

assets: Assets

assets_load :: proc() {
	assert(rl.IsWindowReady())

	assets = Assets {
		normal_font   = raw.font_load_kaplimono_regular(),
		italic_font   = raw.font_load_kapli_italic(),
		boxes         = raw.image_load_boxes(),
		icons         = raw.image_load_icons(),
		dummy_artwork = raw.image_load_dummy_artwork(),
	}
}

assets_destroy :: proc() {
	rl.UnloadTexture(assets.normal_font.texture)
	rl.UnloadTexture(assets.boxes)
}
