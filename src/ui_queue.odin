//
// Current song queue screen. "Song queue" is also referred as "playlist" in MPD.
//

package mupwit

import "lib:mpd"
import "lib:ui"

@(private = "file")
self: struct {
	box:            ui.Box,
	scroll:         ui.Scroll,
	hovering_index: Maybe(int),
}

queue_ui_update :: proc(dt: Seconds) {
	ui.scroll_update(self.box, &self.scroll, dt)

	{
		index, ok := ui.scroll_hovering_item(
			self.box,
			&self.scroll,
			len(state.player.queue),
			SONG_HEIGHT,
		)
		self.hovering_index = index if ok else nil
	}

	if ui.is_mouse_released(.Left) {
		_queue_ui_play_hovering_song()
	}
}

_queue_ui_play_hovering_song :: proc() -> (ok: bool) {
	hovering := self.hovering_index.? or_return
	player_play_song(mpd.Song_Index(hovering))
	return true
}

queue_ui_on_scroll :: proc(scroll: f32, touchpad: bool) {
	ui.scroll_on_scroll(&self.scroll, scroll, touchpad)
}

queue_ui_draw :: proc(ctx: ^ui.Context) {
	player := &state.player

	ui.begin_box(ctx, ui.pad_b(ctx.box, PLAYER_HEIGHT), GAP)
	self.box = ctx.box

	from, to := ui.scroll_visible_items(ctx.box, &self.scroll, len(player.queue), SONG_HEIGHT)

	for i in from ..< to {
		song := &player.queue[i]
		y := i32(i) * SONG_HEIGHT - i32(self.scroll.offset)

		song_draw(ctx, song, y, i == self.hovering_index)
	}

	contents := i32(len(player.queue)) * SONG_HEIGHT
	ui.scroll_draw(ctx, &self.scroll, contents, LIGHT_GRAY)
}

song_draw :: proc(ctx: ^ui.Context, song: ^mpd.Song, y: i32, hovering: bool) {
	rect := ctx.box
	rect.y += y
	rect.height = SONG_HEIGHT

	if hovering {
		ui.draw_box_rounded(ctx, rect, LIGHT_GRAY, filled = true)
	}

	// Current marker.
	if song_is_current(song) {
		pos := rect_pos(rect) - ICON_SIZE / 2
		pos.y += rect.height / 2
		draw_icon(ctx, .Small_Arrow_Right, pos, BLACK)
	}

	ui.begin_box(ctx, rect, GAP)

	// Draw song cover.
	{
		rect := ctx.box
		rect.width = SONG_COVER_SIZE
		rect.height = SONG_COVER_SIZE
		ui.draw_box(ctx, rect, BLACK)
		draw_icon(ctx, .Disk, icon_center_inside(rect), BLACK)
	}

	// Draw song duration.
	duration_advance: i32
	{
		glyphs := ui.text_glyphs(ctx, song.duration_str)
		defer ui.text_glyphs_delete(glyphs)

		ext := ui.measure_glyphs(ctx, glyphs)
		pos := rect_pos(ctx.box)
		pos.x += ctx.box.width - i32(ext.x_advance)
		pos.y += ctx.box.height / 2 - i32(ext.height / 2 - ext.height)
		duration_advance = i32(ext.x_advance)

		ui.draw_glyphs(ctx, glyphs, pos, GRAY)
	}

	// Draw song title and artist.
	{
		box := ctx.box
		box.width += -duration_advance - GAP
		ui.begin_box(ctx, box, 0)

		pos := rect_pos(ctx.box)
		pos.x += SONG_COVER_SIZE + GAP
		pos.y += ctx.font_height - 1
		pos.y += ctx.box.height / 2 - (ctx.font_height * 2 + GAP / 2) / 2

		ui.draw_text(ctx, song.title, pos, BLACK)
		pos.y += ctx.font_height + GAP / 2
		ui.draw_text(ctx, song.artist, pos, GRAY)
	}
}
