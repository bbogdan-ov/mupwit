package mupwit

import "lib:mpd"

@(private = "file")
ui: struct {
	scroll: Scroll,
}

queue_ui_update :: proc(dt: Seconds) {
	scroll_update(&ui.scroll, dt)
}

queue_on_scroll :: proc(scroll: f32, touchpad: bool) {
	scroll_on_scroll(&ui.scroll, scroll, touchpad)
}

queue_ui_draw :: proc(ctx: ^Context) {
	begin_container(ctx, rect_expand(ctx.container, -GAP))

	from, to := scroll_visible_items_range(ctx, &ui.scroll, SONG_HEIGHT)
	to = min(to, len(state.player.queue))

	hovering := scroll_hovering_item_index(ctx, &ui.scroll, SONG_HEIGHT)

	for i in from ..< to {
		song := &state.player.queue[i]
		y := i32(i) * SONG_HEIGHT - i32(ui.scroll.offset)

		song_draw(ctx, song, y, i == hovering)
	}

	contents := i32(len(state.player.queue)) * SONG_HEIGHT
	scroll_draw(ctx, &ui.scroll, contents)
}

song_draw :: proc(ctx: ^Context, song: ^mpd.Song, y: i32, hovering: bool) {
	rect := ctx.container
	rect.y += y
	rect.height = SONG_HEIGHT

	if hovering {
		draw_box_rounded(ctx, rect, LIGHT_GRAY, filled = true)
	}

	// Current marker.
	if song_is_current(song) {
		pos := rect_pos(rect) - ICON_SIZE / 2
		pos.y += rect.height / 2
		draw_icon(ctx, .Small_Arrow_Right, pos, BLACK)
	}

	begin_container(ctx, rect_expand(rect, -GAP))

	// Draw song cover.
	{
		rect := ctx.container
		rect.width = SONG_COVER_SIZE
		rect.height = SONG_COVER_SIZE
		draw_box(ctx, rect, BLACK)
		draw_icon(ctx, .Disk, rect_center(rect) - ICON_SIZE / 2, BLACK)
	}

	// Draw song duration.
	duration_advance: i32
	{
		glyphs := text_glyphs(ctx, song.duration_str)
		defer text_glyphs_delete(glyphs)

		ext := measure_glyphs(ctx, glyphs)
		pos := rect_pos(ctx.container)
		pos.x += ctx.container.width - i32(ext.x_advance)
		pos.y += ctx.container.height / 2 - i32(ext.height / 2 - ext.height)
		duration_advance = i32(ext.x_advance)

		draw_glyphs(ctx, glyphs, pos, GRAY)
	}

	// Draw song title and artist.
	{
		cont := ctx.container
		cont.width += -duration_advance - GAP
		begin_container(ctx, cont)

		pos := rect_pos(ctx.container)
		pos.x += SONG_COVER_SIZE + GAP
		pos.y += ctx.font_height - 1
		pos.y += ctx.container.height / 2 - (ctx.font_height * 2 + GAP / 2) / 2

		draw_text(ctx, song.title, pos, BLACK)
		pos.y += ctx.font_height + GAP / 2
		draw_text(ctx, song.artist, pos, GRAY)
	}
}
