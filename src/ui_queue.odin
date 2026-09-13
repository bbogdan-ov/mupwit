package mupwit

import "lib:mpd"
import "lib:ui"

@(private = "file")
queue_ui: struct {
	scroll: ui.Scroll,
}

queue_ui_update :: proc(dt: Seconds) {
	ui.scroll_update(&queue_ui.scroll, dt)
}

queue_ui_on_scroll :: proc(scroll: f32, touchpad: bool) {
	ui.scroll_on_scroll(&queue_ui.scroll, scroll, touchpad)
}

queue_ui_draw :: proc(ctx: ^ui.Context) {
	cont := ctx.container
	cont.height -= PLAYER_HEIGHT
	ui.begin_container(ctx, cont, GAP)

	from, to := ui.scroll_visible_items_range(ctx, &queue_ui.scroll, SONG_HEIGHT)
	to = min(to, len(state.player.queue))

	hovering := ui.scroll_hovering_item_index(ctx, &queue_ui.scroll, SONG_HEIGHT)

	for i in from ..< to {
		song := &state.player.queue[i]
		y := i32(i) * SONG_HEIGHT - i32(queue_ui.scroll.offset)

		song_draw(ctx, song, y, i == hovering)
	}

	contents := i32(len(state.player.queue)) * SONG_HEIGHT
	ui.scroll_draw(ctx, &queue_ui.scroll, contents, LIGHT_GRAY)
}

song_draw :: proc(ctx: ^ui.Context, song: ^mpd.Song, y: i32, hovering: bool) {
	rect := ctx.container
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

	ui.begin_container(ctx, rect, GAP)

	// Draw song cover.
	{
		rect := ctx.container
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
		pos := rect_pos(ctx.container)
		pos.x += ctx.container.width - i32(ext.x_advance)
		pos.y += ctx.container.height / 2 - i32(ext.height / 2 - ext.height)
		duration_advance = i32(ext.x_advance)

		ui.draw_glyphs(ctx, glyphs, pos, GRAY)
	}

	// Draw song title and artist.
	{
		cont := ctx.container
		cont.width += -duration_advance - GAP
		ui.begin_container(ctx, cont, 0)

		pos := rect_pos(ctx.container)
		pos.x += SONG_COVER_SIZE + GAP
		pos.y += ctx.font_height - 1
		pos.y += ctx.container.height / 2 - (ctx.font_height * 2 + GAP / 2) / 2

		ui.draw_text(ctx, song.title, pos, BLACK)
		pos.y += ctx.font_height + GAP / 2
		ui.draw_text(ctx, song.artist, pos, GRAY)
	}
}
