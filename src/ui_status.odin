//
// Playback status panel that sits at the bottom of the screen and displays the
// currently playing song and elapsed time within it.
//

package mupwit

import "core:fmt"
import "lib:cairo"
import "lib:mpd"

import "lib:ui"

Status_Time_Mode :: enum {
	Time_Left = 0,
	Elapsed,
	Elapsed_Duration,
}

_Status_Visible :: enum {
	Status,
	Sub_Status,
}
Status_Visible :: bit_set[_Status_Visible]

@(private = "file")
self: struct {
	button_play:    ui.Button,
	button_clear:   ui.Button,
	button_shuffle: ui.Button,
	slider:         ui.Slider,
	tween:          ui.Animated(f32),
	sub_tween:      ui.Animated(f32),
	text_rect:      Rect,
	time_rect:      Rect,
	time_mode:      Status_Time_Mode,
	visible:        Status_Visible,
}

status_ui_init :: proc() {
	self.tween.duration = STATUS_REVEAL_ANIM_DURATION
	self.tween.easing = .Sine_In_Out
	self.tween.value = STATUS_MAX_HEIGHT

	self.sub_tween.duration = STATUS_REVEAL_ANIM_DURATION
	self.sub_tween.easing = .Sine_In_Out
	self.sub_tween.value = SUB_STATUS_HEIGHT
}

status_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.animated_update(&self.tween, dt)
	ui.animated_update(&self.sub_tween, dt)

	visible: Status_Visible
	if state.screen == .Queue do visible += {.Sub_Status}
	if state.screen != .Player && state.player.cur_song != nil do visible += {.Status}
	_status_ui_set_visible(visible)

	player := state.player

	if .Status in self.visible {
		if ui.button_update(&self.button_play) {
			player_toggle_play(player)
		}

		if ui.slider_update(&self.slider) {
			player_seek_percent(player, self.slider.progress)
		}

		// TODO: clicking either on a song title or a song artist should
		// navigate to the song in the album and to the artist respectively.
		if ui.is_clicked_inside(.Left, self.text_rect) {
			set_screen(state, .Player)
		}
	}

	if .Sub_Status in self.visible {
		_sub_status_ui_update(state)
	}
}

_sub_status_ui_update :: proc(state: ^State) {
	if ui.button_update(&self.button_clear) {
		player_queue_clear(state.player)
	}
	if ui.button_update(&self.button_shuffle) {
		player_queue_shuffle(state.player)
	}

	if ui.is_pointer_inside(self.time_rect) {
		ui.set_cursor(.Pointer)

		if ui.is_clicked(.Left) {
			self.time_mode = enum_rotate_variant(self.time_mode, 1)
			ui.dirty(true)
		} else if ui.is_clicked(.Right) {
			self.time_mode = enum_rotate_variant(self.time_mode, -1)
			ui.dirty(true)
		}
	}
}

_status_ui_set_visible :: proc(visible: Status_Visible) {
	if self.visible == visible do return
	self.visible = visible

	offset, sub_offset: f32
	switch self.visible {
	case {.Status}:
		offset = 0
		sub_offset = SUB_STATUS_HEIGHT
	case {.Sub_Status}:
		offset = STATUS_HEIGHT
		sub_offset = 0
	case {.Status, .Sub_Status}:
		offset = 0
		sub_offset = 0
	case:
		offset = STATUS_MAX_HEIGHT
		sub_offset = 0
	}

	ui.play_to(&self.tween, offset)
	ui.play_to(&self.sub_tween, sub_offset)
}

status_ui_visible_height :: proc() -> i32 {
	off := STATUS_MAX_HEIGHT - self.tween.value - self.sub_tween.value
	return max(i32(off), 0)
}

status_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if self.visible == nil && self.tween.timer <= 0 do return

	btn_play := &self.button_play

	rect := ui.state.view
	rect.height = STATUS_HEIGHT
	rect.y = ui.state.view.height - rect.height
	rect.y += i32(self.tween.value)

	{
		r := rect
		r.height = SUB_STATUS_HEIGHT
		r.y -= r.height
		_sub_status_ui_draw(state, ctx, r)
	}

	if self.tween.value >= STATUS_HEIGHT do return

	_status_ui_draw_box(state, ctx, rect)

	ui.guard_box(ctx, rect, GAP)

	// Draw play button.
	icon := icon_from_playstate(state.player.playstate)
	draw_icon_button(state, ctx, btn_play, icon, rect_pos(ctx.box), state.theme.black)

	{
		box := ui.pad_l(ctx.box, btn_play.rect.width + GAP)
		box.width -= GAP
		ui.guard_box(ctx, box)

		offset: Vec2
		offset.y = ctx.box.height / 2
		offset.y += -(ctx.font_height * 2 + ui.SLIDER_THICKNESS) / 2 + ctx.font_height

		self.text_rect = ctx.box.rect
		self.text_rect.height -= ui.SLIDER_CLICK_THICKNESS

		// Draw song title and artist.
		song, has_song := player_cur_or_last_song(state.player)
		if has_song {
			title := song.title
			artist := song.artist
			// TODO: truncate URI only to the filename (not a full path).
			if len(title) == 0 do title = string(song.file)
			if len(artist) == 0 do artist = UNKNOWN

			pos := rect_pos(ctx.box) + offset
			pos.x += ui.draw_text(ctx, title, pos, state.theme.black).x
			pos.x += ui.draw_text(ctx, fmt.tprint(" -", artist), pos, state.theme.gray).x
		}

		// Draw slider.
		{
			rect := ctx.box
			rect.height = ui.SLIDER_THICKNESS
			rect.y += offset.y + ctx.font_height

			progress := player_progress(state.player)
			gray := state.theme.gray
			ui.slider_draw(
				ctx,
				&self.slider,
				progress,
				rect,
				state.theme.black,
				gray,
				thumb = false,
			)
		}
	}
}

_sub_status_ui_draw :: proc(state: ^State, ctx: ^ui.Context, rect: Rect) {
	player := state.player

	rect := rect
	rect.y += i32(self.sub_tween.value)
	ui.guard_box(ctx, rect, {GAP * 2, 0})

	_status_ui_draw_box(state, ctx, rect)

	{
		r := ctx.box
		r.width /= 2
		r.x = ctx.box.x + ctx.box.width - r.width
		self.time_rect = r
	}

	pos := rect_pos(ctx.box)
	pos.y += ctx.box.height / 2 - TINY_BUTTON_SIZE / 2

	// TODO: move these buttons into a context menu to not clutter the UI.
	// Draw action buttons.
	{
		btn :: draw_action_button
		G :: GAP / 2

		pos.x -= 2
		pos.x += btn(state, ctx, &self.button_shuffle, .Shuffle_Queue, pos) + G
		pos.x += btn(state, ctx, &self.button_clear, .Clear_Queue, pos) + G
	}

	pos.x += GAP
	pos.y = ctx.box.y + ctx.font_height
	pos.y += ctx.box.height / 2 - ctx.font_height / 2

	// Draw number of songs.
	{
		count_str := fmt.tprint("♪", len(player.queue))
		ui.draw_text(ctx, count_str, pos, state.theme.gray)
	}

	// Draw time.
	{
		elapsed := player.queue_elapsed + player.elapsed
		duration := player.queue_duration
		time_str := _sub_status_ui_time(elapsed, duration)

		pos.x = ctx.box.x + ctx.box.width
		ui.draw_text(ctx, time_str, pos, state.theme.gray, align = .End)
	}
}

_sub_status_ui_time :: proc(elapsed, duration: Seconds) -> string {
	elapsed := mpd.Seconds(elapsed)
	duration := mpd.Seconds(duration)

	switch self.time_mode {
	case .Time_Left:
		return fmt.tprint(elapsed - duration)
	case .Elapsed:
		return fmt.tprint(elapsed)
	case .Elapsed_Duration:
		return fmt.tprint(elapsed, '/', duration)
	case:
		unreachable()
	}
}

_status_ui_draw_box :: proc(state: ^State, cr: ^cairo.cairo_t, rect: Rect) {
	ui.draw_rect(cr, rect, state.theme.background)
	ui.draw_line_h(cr, rect, state.theme.gray)
}
