package ui

import rl "vendor:raylib"

import raw "../../build/assets"

Assets :: struct #all_or_none {
	normal_font: rl.Font,
	boxes:       rl.Texture,
}

assets: Assets

assets_load :: proc() {
	assert(rl.IsWindowReady())

	assets = Assets {
		normal_font = raw.font_load_kaplimono_regular(),
		boxes       = raw.image_load_boxes(),
	}
}

assets_destroy :: proc() {
	rl.UnloadTexture(assets.normal_font.texture)
	rl.UnloadTexture(assets.boxes)
}
