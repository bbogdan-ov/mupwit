package ui

Assets :: struct #all_or_none {
	normal_font:   Font,
	italic_font:   Font,
	boxes:         Texture,
	icons:         Texture,
	dummy_artwork: Texture,
}

assets: Assets

assets_destroy :: proc() {
	unload_font(assets.normal_font)
	unload_font(assets.italic_font)
	unload_texture(assets.boxes)
	unload_texture(assets.icons)
	unload_texture(assets.dummy_artwork)
}
