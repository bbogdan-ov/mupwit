package mupwit

import "../lib/mpd"
import "../lib/ui"

@(private)
_SONG_HEIGHT :: QUEUE_SONG_COVER_SIZE + GAP * 2

Queue_Page :: struct #all_or_none {
	scroll: ui.Scroll,
}

queue_page_create :: proc() -> Queue_Page {
	return Queue_Page{scroll = ui.scroll_create()}
}

queue_page_draw :: proc(page: ^Queue_Page) {
	container := ui.rect_shrink(ui.window_rect(), GAP, GAP)

	ui.scroll_update(&page.scroll, f32(len(queue.songs) * _SONG_HEIGHT), container.height)

	ui.scroll_draw(page.scroll, container, GAP / 2 - ui.SCROLL_THICKNESS / 2, LIGHTGRAY)

	// TODO: temporary
	if len(queue.songs) == 0 {
		draw_normal_text("no songs", {container.x, container.y})
		return
	}

	// Draw list of songs
	loop: for &song, idx in queue.songs {
		y := container.y + f32(idx * _SONG_HEIGHT) - page.scroll.offset

		// Don't draw songs above the screen
		if y + _SONG_HEIGHT < 0 do continue
		// Don't draw songs below the screen
		if y > container.height do break loop

		_draw_song(&song, y, container)
	}
}

@(private)
_draw_song :: proc(song: ^mpd.Song, y: f32, container: ui.Rect) {
	rect := ui.Rect{container.x, y, container.width, _SONG_HEIGHT}
	offset := ui.Point{rect.x, rect.y}

	dur_size := ui.measure_text(assets.normal_font, song.duration_text)
	ui.begin_text_truncate(rect.x + GAP, rect.width - GAP * 2 - (dur_size.x + GAP * 2))

	is_hovering := ui.rect_contains_point(rect, ui.window.mouse)
	if is_hovering {
		// Draw background
		draw_box(.Filled_Rounded, rect, LIGHTGRAY)
	}

	// Draw "currently playing" marker
	if cur_song, ok := player.song.?; ok && cur_song.id == song.id {
		x := rect.x - ICON_SIZE / 2
		y := rect.y + rect.height / 2 - ICON_SIZE / 2
		draw_icon(.Small_Arrow_Right, {x, y})
	}

	// Draw song cover
	offset.x += GAP
	offset.y += GAP
	cover_rect := ui.Rect{offset.x, offset.y, QUEUE_SONG_COVER_SIZE, QUEUE_SONG_COVER_SIZE}
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
		offset.y += -GAP + _SONG_HEIGHT / 2 - f32(assets.normal_font.size) - 3

		title := song.title.? or_else UNKNOWN
		artist := song.artist.? or_else UNKNOWN

		offset.y += draw_normal_text(title, offset).y
		draw_normal_text(artist, offset, GRAY)
	}

	ui.end_text_truncate()

	// Draw song duration
	{
		x := rect.x + rect.width - dur_size.x - GAP
		y := rect.y + rect.height / 2 - dur_size.y / 2 - 3
		draw_normal_text(song.duration_text, {x, y}, GRAY)
	}
}
