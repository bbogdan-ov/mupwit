package pages

import "core:fmt"
import rl "vendor:raylib"

import "../ui"
import "../wheel"

player_draw :: proc(player: ^wheel.Player) {
	GAP :: 8

	sw := f32(rl.GetScreenWidth())
	size := f32(ui.assets.dummy_artwork.width / 4)
	margin := (sw - size) / 2

	offset := rl.Vector2{margin, margin}

	ui.draw_anim_texture(ui.assets.dummy_artwork, offset, {}, {4, 1})
	ui.draw_box(.Thick, {offset.x, offset.y, size, size})
	offset.y += size + GAP

	if song, ok := player.song.?; ok {
		title := ui.frame_cstring(song.title.? or_else "<unknown>")
		artist_and_album := fmt.aprintf(
			"%s - %s",
			song.artist.? or_else "<unknown>",
			song.album.? or_else "<unknown>",
			allocator = ui.state.frame_allocator,
		)
		aaa := ui.frame_cstring(artist_and_album)

		offset.y += ui.draw_italic_text(title, offset, scale = 2)
		offset.y += ui.draw_text(aaa, offset, ui.GRAY)
		offset.y += GAP * 2
	}
}
