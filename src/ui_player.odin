package mupwit

import "core:fmt"
import "lib:cairo"
import "lib:mpd"
import "lib:ui"

@(private = "file")
self: struct {
	button_prev:        ui.Button,
	button_play:        ui.Button,
	button_next:        ui.Button,
	slider:             ui.Slider,
	cover:              Maybe(^Cover),
	loading_cover:      Maybe(^Cover),
	update_cover_timer: Seconds,
}

player_ui_update :: proc(state: ^State, dt: Seconds) {
	if state.screen != .Player do return
	player := &state.player

	if ui.button_update(&self.button_prev) {
		player_previous(player)
	}
	if ui.button_update(&self.button_play) {
		player_toggle_play(player)
	}
	if ui.button_update(&self.button_next) {
		player_next(player)
	}

	if ui.slider_update(&self.slider) {
		player_seek_percent(player, self.slider.progress)
	}
	if ui.slider_is_dragging(&self.slider) {
		secs := player.duration * Seconds(self.slider.progress)
		player.elapsed = secs
	}

	if self.update_cover_timer > 0 {
		self.update_cover_timer -= dt

		if self.update_cover_timer <= 0 {
			_player_ui_update_song_cover(state)
		}
	}

	if cover, ok := self.loading_cover.?; ok {
		if !cover.loading {
			_player_ui_set_cover(cover)
			self.loading_cover = nil
		}
	}
}

player_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if state.screen != .Player do return

	player := &state.player
	song, has_song := player_cur_song(player)

	ui.begin_box(ctx, ctx.box, PLAYER_PADDING)

	offset: Vec2

	// Draw current song cover.
	{
		rect := ctx.box.rect
		rect.height = rect.width

		cover, has_cover := self.cover.?
		if has_cover {
			if surface, ok := cover.surface.?; ok {
				cairo.set_source_surface(ctx, surface, f64(rect.x), f64(rect.y))
				cairo.paint(ctx)
			} else if !cover.loading {
				ui.draw_rect(ctx, rect, GRAY)
			}
		}

		ui.draw_box_bulgy(ctx, ui.pad(rect, -1), BLACK)
		offset.y += rect.height
	}

	if has_song {
		offset.y += GAP * 3

		pos := rect_pos(ctx.box) + offset
		height := ctx.font_height * 2 + GAP

		pos.y += ctx.font_height
		pos.y += ICON_BUTTON_SIZE / 2 - height / 2
		ui.draw_text(ctx, song.title, pos, BLACK, bold = true)
		pos.y += ctx.font_height + GAP / 2

		artist := fmt.tprint(song.artist, '-', song.album)
		ui.draw_text(ctx, artist, pos, GRAY)

		offset.y += height
	}

	// Draw slider.
	{
		offset.y += GAP * 3
		ui.begin_box(ctx, ui.pad_t(ctx.box, offset.y))
		offset.y += _player_ui_draw_slider(state, ctx)
	}

	// Draw control buttons.
	{
		btn :: draw_icon_button

		offset.y -= GAP

		rect: Rect
		rect.y = ctx.box.y + offset.y
		rect.width = ICON_BUTTON_SIZE * 3
		rect.height = ICON_BUTTON_SIZE
		rect.x = ctx.box.x + ctx.box.width / 2 - rect.width / 2

		play_icon := icon_from_playstate(player.playstate)

		pos := rect_pos(rect)
		pos.x += btn(state, ctx, &self.button_prev, .Previous, pos, BLACK)
		pos.x += btn(state, ctx, &self.button_play, play_icon, pos, BLACK)
		pos.x += btn(state, ctx, &self.button_next, .Next, pos, BLACK)

		offset.y += rect.height
	}
}

_player_ui_draw_slider :: proc(state: ^State, ctx: ^ui.Context) -> (height: i32) {
	player := &state.player

	elapsed_str := mpd.format_seconds(mpd.Seconds(player.elapsed), context.temp_allocator)
	duration_str := mpd.format_seconds(mpd.Seconds(player.duration), context.temp_allocator)

	rect := ctx.box.rect
	rect.y += height
	rect.height = ui.SLIDER_THICKNESS

	progress := player_progress(player)
	ui.slider_draw(ctx, &self.slider, progress, rect, BLACK, GRAY)
	height += rect.height

	height += ctx.font_height * 2

	pos := rect_pos(ctx.box)
	pos.y += height
	ui.draw_text(ctx, elapsed_str, pos, GRAY)
	pos.x += ctx.box.width
	ui.draw_text(ctx, duration_str, pos, GRAY, align = .End)
	height += ctx.font_height

	return height
}

player_ui_on_cur_song_updated :: proc(state: ^State) {
	_player_ui_defer_song_cover_update(state)
}

_player_ui_defer_song_cover_update :: proc(state: ^State) {
	song, has_song := player_cur_song(&state.player)
	if has_song {
		cover, has_cover := cover_get(&state.player, song.file, song.album, .Huge)
		if has_cover {
			_player_ui_set_cover(cover_ref(cover))
		} else {
			self.update_cover_timer = PLAYER_COVER_UPDATE_DELAY
		}
	} else {
		_player_ui_set_cover(nil)
	}
}

_player_ui_update_song_cover :: proc(state: ^State) {
	song, has_song := player_cur_song(&state.player)
	if has_song {
		cover := cover_get_or_request(&state.player, song.file, song.album, .Huge)
		if cover.loading {
			// Do not set the new cover right away if it is loading. We'll wait
			// for the new cover to load and only then apply it.
			self.loading_cover = cover_ref(cover)
		} else {
			_player_ui_set_cover(cover_ref(cover))
		}
	} else {
		_player_ui_set_cover(nil)
	}
}

_player_ui_set_cover :: proc(cover: Maybe(^Cover)) {
	if self.cover == cover do return

	if cur, ok := self.cover.?; ok {
		assert(cur.ref_count >= 2)
		cover_unref(cur)
	}
	self.cover = cover
}
