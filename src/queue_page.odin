package mupwit

import "../lib/mpd"
import "../lib/ui"

GAP :: 8

SONG_COVER_SIZE :: 32
SONG_HEIGHT :: SONG_COVER_SIZE + GAP * 2

queue_page_draw :: proc(queue: Queue) {
	GAP :: 10

	pos := ui.Point{10, 10}

	if len(queue.songs) == 0 {
		draw_normal_text("no songs", pos)
		return
	}

	loop: for &song, idx in queue.songs {
		y := f32(GAP + idx * SONG_HEIGHT)

		// Don't draw songs above the screen
		if y + SONG_HEIGHT < 0 do continue
		// Don't draw songs below the screen
		if i32(y) > ui.window.height do break loop

		_draw_song(&song, y)
	}
}

@(private)
_draw_song :: proc(song: ^mpd.Song, y: f32) {
	rect := ui.Rect{GAP, y, f32(ui.window.width) - GAP * 2, SONG_HEIGHT}

	offset := ui.Point{rect.x, rect.y}

	is_hovering := ui.rect_contains_point(rect, ui.window.mouse)

	if is_hovering {
		// Draw background
		draw_box(.Filled_Rounded, rect, LIGHTGRAY)
	}

	// Draw song cover
	offset.x += GAP
	offset.y += GAP
	cover_rect := ui.Rect{offset.x, offset.y, SONG_COVER_SIZE, SONG_COVER_SIZE}
	{
		draw_box(.Normal, cover_rect)

		// Draw disk icon in the center of the rect
		icon_pos := ui.Point {
			cover_rect.x + cover_rect.width / 2 - ICON_SIZE / 2,
			cover_rect.y + cover_rect.height / 2 - ICON_SIZE / 2,
		}
		draw_icon(.Disk, icon_pos)
	}

	// Draw song info
	{
		offset.x += cover_rect.width + GAP
		offset.y += -GAP + SONG_HEIGHT / 2 - f32(assets.normal_font.size) - 4

		title := song.title.? or_else UNKNOWN
		artist := song.artist.? or_else UNKNOWN

		offset.y += draw_normal_text(title, offset)
		draw_normal_text(artist, offset, GRAY)
	}
}
