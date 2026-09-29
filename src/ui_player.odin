package mupwit

import "core:fmt"
import "core:math/ease"

import "lib:mpd"
import "lib:ui"

@(private = "file")
self: struct {
	button_prev:       ui.Button,
	button_play:       ui.Button,
	button_next:       ui.Button,
	slider:            ui.Slider,
	cover_tween:       ui.Tween(f32),
	prev_cover, cover: Maybe(^Cover),
	loading_cover:     Maybe(^Cover),
	req_cover_timer:   Seconds,
}

player_ui_destroy :: proc() {
	cover_maybe_unref(self.prev_cover)
	cover_maybe_unref(self.cover)
	cover_maybe_unref(self.loading_cover)
}

player_ui_update :: proc(state: ^State, dt: Seconds) {
	_player_ui_update_cover_handling(state, dt)

	if state.screen != .Player {
		ui.tween_finish(&self.cover_tween)
		return
	}

	player := &state.player

	ui.tween_update(&self.cover_tween, dt)

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
}

_player_ui_update_cover_handling :: proc(state: ^State, dt: Seconds) {
	if self.req_cover_timer > 0 {
		self.req_cover_timer -= dt

		if self.req_cover_timer <= 0 {
			_player_ui_request_cur_cover(state)
		}
	}

	loading, has_loading := self.loading_cover.?
	if has_loading && !loading.loading {
		_player_ui_set_cover(state, cover_ref(loading))
	}
}

player_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if !screen_is_visible(state, .Player) do return

	player := &state.player
	song, has_song := player_cur_or_last_song(player)

	box := ctx.box
	box.x += screen_x_offset(state, .Player)
	ui.begin_box(ctx, box, PLAYER_PADDING)

	offset: Vec2

	// Draw current song cover.
	{
		rect := cover_rect(.Huge, rect_pos(ctx.box))

		// TODO: would be cool to allow double-click on the cover and open it
		// in an external image viewer.

		// TODO: i should keep N next covers in an array and scroll through
		// them when the current song changes to get a smoother animation when
		// switching songs very fast. Currently if you switch a song too fast
		// the animation immidietely "snaps" if it is not finished yet.
		dir: i32
		easing := ease.Ease.Cubic_In_Out
		switch player.switch_direction {
		case .From_None:
			easing = .Cubic_Out
			dir = 1
		case .To_None:
			easing = .Cubic_In
			dir = 1
		case .Next:
			dir = 1
		case .Previous:
			dir = -1
		}

		progress := ui.tween_ease(&self.cover_tween, 1, easing)
		vw := f32(ui.state.view.width)
		if progress < 1 {
			r := rect
			r.x -= i32(vw * progress) * dir
			_player_ui_draw_cover(state, ctx, self.prev_cover, r)
		}

		{
			r := rect
			r.x += i32(vw * (1 - progress)) * dir
			_player_ui_draw_cover(state, ctx, self.cover, r)
		}

		offset.y += rect.height
	}

	// Draw song info.
	if has_song {
		offset.y += GAP * 3

		pos := rect_pos(ctx.box) + offset
		height := ctx.font_height * 2 + GAP

		pos.y += ctx.font_height
		pos.y += ICON_BUTTON_SIZE / 2 - height / 2
		ui.draw_text(ctx, song.title, pos, state.theme.black, bold = true)
		pos.y += ctx.font_height + GAP / 2

		artist := fmt.tprint(song.artist, '-', song.album)
		ui.draw_text(ctx, artist, pos, state.theme.gray)

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
		color := state.theme.black

		rect: Rect
		rect.y = ctx.box.y + offset.y
		rect.width = ICON_BUTTON_SIZE * 3
		rect.height = ICON_BUTTON_SIZE
		rect.x = ctx.box.x + ctx.box.width / 2 - rect.width / 2

		play_icon := icon_from_playstate(player.playstate)

		pos := rect_pos(rect)
		pos.x += btn(state, ctx, &self.button_prev, .Previous, pos, color)
		pos.x += btn(state, ctx, &self.button_play, play_icon, pos, color)
		pos.x += btn(state, ctx, &self.button_next, .Next, pos, color)

		offset.y += rect.height
	}
}

_player_ui_draw_cover :: proc(state: ^State, ctx: ^ui.Context, cover: Maybe(^Cover), rect: Rect) {
	if cover == nil do return

	drawn := cover_draw(ctx, cover, rect_pos(rect))
	if !drawn {
		// TODO: draw a proper placeholder.
		ui.draw_rect(ctx, rect, state.theme.gray)
	}

	ui.draw_box_bulgy(ctx, ui.pad(rect, -1), state.theme.black)
}

_player_ui_draw_slider :: proc(state: ^State, ctx: ^ui.Context) -> (height: i32) {
	player := &state.player

	elapsed_str := fmt.tprint(mpd.Seconds(player.elapsed))
	duration_str := fmt.tprint(mpd.Seconds(player.duration))

	rect := ctx.box.rect
	rect.y += height
	rect.height = ui.SLIDER_THICKNESS

	progress := player_progress(player)
	ui.slider_draw(ctx, &self.slider, progress, rect, state.theme.black, state.theme.gray)
	height += rect.height

	height += ctx.font_height * 2

	pos := rect_pos(ctx.box)
	pos.y += height
	ui.draw_text(ctx, elapsed_str, pos, state.theme.gray)
	pos.x += ctx.box.width
	ui.draw_text(ctx, duration_str, pos, state.theme.gray, align = .End)
	height += ctx.font_height

	return height
}

player_ui_on_cur_song_updated :: proc(state: ^State) {
	song, has_song := player_cur_song(&state.player)
	if !has_song {
		_player_ui_set_cover(state, nil)
		return
	}

	cover, has_cover := cover_get(&state.player, song.file, song.album, .Huge)
	if has_cover {
		_player_ui_set_cover(state, cover_ref(cover))
	} else {
		self.req_cover_timer = COVER_REQ_DELAY
	}
}

_player_ui_request_cur_cover :: proc(state: ^State) {
	COVER_SIZE :: Cover_Size.Huge

	song, has_song := player_cur_song(&state.player)
	if !has_song {
		_player_ui_set_cover(state, nil)
		return
	}

	cover := cover_get_or_request(&state.player, song.file, song.album, COVER_SIZE)
	if cover.loading {
		cover_maybe_unref(self.loading_cover)

		// Do not set the new cover right away if it is loading. We'll wait
		// for the new cover to load and only then apply it.
		self.loading_cover = cover_ref(cover)
	} else {
		_player_ui_set_cover(state, cover_ref(cover))
	}
}

// FIXME!!: sometimes it may not update the cover when the current song changes.
// It happens very rearly an i'm not sure why, it seem to only happen when you
// play switch albums.
_player_ui_set_cover :: proc(state: ^State, cover: Maybe(^Cover)) {
	cover_maybe_unref(self.prev_cover)
	self.prev_cover = self.cover
	self.cover = cover

	cover_maybe_unref(self.loading_cover)
	self.loading_cover = nil

	ui.tween_play(&self.cover_tween, 0, PLAYER_COVER_ANIM_DURATION)

	if PLAYER_ADAPT_THEME_TO_COVER {
		if cover, ok := cover.?; ok {
			set_background_from_cover(state, cover)
		} else {
			set_background(state, DEFAULT_BACKGROUND)
		}
	}
}
