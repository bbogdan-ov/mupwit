package mupwit

import "core:fmt"

import "ui"

player_page_draw :: proc(player: ^Player) {
	GAP :: 8

	ww := f32(ui.window.width)
	size := f32(ui.assets.dummy_artwork.width / 4)
	margin := (ww - size) / 2

	offset := ui.Point{margin, margin}

	ui.draw_texture_anim(ui.assets.dummy_artwork, offset, {}, {4, 1})
	ui.draw_box(.Thick, {offset.x, offset.y, size, size})
	offset.y += size + GAP * 2

	if song, ok := player.song.?; ok {
		title := song.title.? or_else "<unknown>"
		artist_and_album := fmt.tprintf(
			"%s - %s",
			song.artist.? or_else "<unknown>",
			song.album.? or_else "<unknown>",
		)

		offset.y += ui.draw_italic_text(title, offset, scale = 2)
		offset.y += ui.draw_text(artist_and_album, offset, ui.THEME_GRAY)
		offset.y += GAP * 2
	}
}
