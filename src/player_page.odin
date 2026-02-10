package mupwit

import "core:fmt"

import "ui"

player_page_draw :: proc(player: ^Player) {
	GAP :: 8

	ww := f32(ui.window.width)
	artwork_size := f32(ui.assets.dummy_artwork.width / 4)
	margin := (ww - artwork_size) / 2

	offset := ui.Point{margin, margin}

	ui.draw_texture_anim(ui.assets.dummy_artwork, offset, {}, {4, 1})
	ui.draw_box(.Thick, {offset.x, offset.y, artwork_size, artwork_size})
	offset.y += artwork_size + GAP * 2

	if song, ok := player.song.?; ok {
		title := song.title.? or_else "<unknown>"
		artist_and_album := fmt.tprintf(
			"%s - %s",
			song.artist.? or_else "<unknown>",
			song.album.? or_else "<unknown>",
		)

		offset.y += ui.draw_italic_text(title, offset, scale = 2, max_width = artwork_size) + GAP
		offset.y += ui.draw_text(artist_and_album, offset, ui.THEME_GRAY, max_width = artwork_size)
		offset.y += GAP * 2
	}
}
