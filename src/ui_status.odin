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

@(private = "file")
self: struct {
	button_play:      ui.Button,
	button_clear:     ui.Button,
	button_shuffle:   ui.Button,
	slider:           ui.Slider,
	tween:            ui.Tween(f32),
	queue_tween:      ui.Tween(f32),
	time_rect:        Rect,
	time_mode:        Status_Time_Mode,
	offset:           f32,
	queue_offset:     f32,
	cur_offset:       i32,
	cur_queue_offset: i32,
}

status_ui_init :: proc() {
	self.offset = STATUS_MAX_HEIGHT
}

status_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.tween_update(&self.tween, dt)
	ui.tween_update(&self.queue_tween, dt)

	off := ui.tween_ease(&self.tween, self.offset, .Sine_In_Out)
	self.cur_offset = i32(off)
	off = ui.tween_ease(&self.queue_tween, self.queue_offset, .Sine_In_Out)
	self.cur_queue_offset = i32(off)

	switch {
	case state.screen == .Player:
		// Hide both queue status and this one.
		_status_ui_set_offset(STATUS_MAX_HEIGHT)
		return
	case state.player.cur_song == nil:
		// Hide only the status, queue status may be visible.
		_status_ui_set_offset(STATUS_HEIGHT)
	case:
		// Show.
		_status_ui_set_offset(0)
	}

	if state.screen == .Queue {
		_status_ui_set_queue_offset(0)
	} else {
		_status_ui_set_queue_offset(QUEUE_STATUS_HEIGHT)
	}

	player := &state.player

	if self.cur_offset == 0 {
		if ui.button_update(&self.button_play) {
			player_toggle_play(player)
		}

		if ui.slider_update(&self.slider) {
			player_seek_percent(player, self.slider.progress)
		}
	}

	if self.cur_queue_offset == 0 {
		_queue_status_ui_update(state)
	}
}

status_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	if self.cur_offset >= STATUS_MAX_HEIGHT do return

	btn_play := &self.button_play

	rect := ui.state.view
	rect.height = STATUS_HEIGHT
	rect.y = ui.state.view.height - rect.height
	rect.y += self.cur_offset

	{
		r := rect
		r.height = QUEUE_STATUS_HEIGHT
		r.y -= r.height
		_queue_status_ui_draw(state, ctx, r)
	}

	if self.cur_offset >= STATUS_HEIGHT do return

	_status_ui_draw_box(state, ctx, rect)

	ui.begin_box(ctx, rect, GAP)

	// Draw play button.
	icon := icon_from_playstate(state.player.playstate)
	draw_icon_button(state, ctx, btn_play, icon, rect_pos(ctx.box), state.theme.black)

	{
		box := ui.pad_l(ctx.box, btn_play.rect.width + GAP)
		box.width -= GAP
		ui.begin_box(ctx, box)

		offset: Vec2
		offset.y = ctx.box.height / 2
		offset.y += -(ctx.font_height * 2 + ui.SLIDER_THICKNESS) / 2 + ctx.font_height

		// Draw song title and artist.
		song, has_song := player_cur_or_last_song(&state.player)
		if has_song {
			pos := rect_pos(ctx.box) + offset
			pos.x += ui.draw_text(ctx, song.title, pos, state.theme.black).x
			pos.x += ui.draw_text(ctx, fmt.tprint(" -", song.artist), pos, state.theme.gray).x
		}

		// Draw slider.
		{
			rect := ctx.box
			rect.height = ui.SLIDER_THICKNESS
			rect.y += offset.y + ctx.font_height

			progress := player_progress(&state.player)
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

_queue_status_ui_update :: proc(state: ^State) {
	if ui.button_update(&self.button_clear) {
		player_clear_queue(&state.player)
	}
	if ui.button_update(&self.button_shuffle) {
		player_shuffle_queue(&state.player)
	}

	if ui.is_pointer_inside(self.time_rect) {
		ui.set_cursor(.Pointer)

		if ui.is_clicked(.Left) {
			self.time_mode = enum_rotate_variant(self.time_mode, 1)
		} else if ui.is_clicked(.Right) {
			self.time_mode = enum_rotate_variant(self.time_mode, -1)
		}
	}
}

_queue_status_ui_draw :: proc(state: ^State, ctx: ^ui.Context, rect: Rect) {
	H_GAP :: GAP * 2

	player := &state.player

	rect := rect
	rect.y += self.cur_queue_offset

	{
		r := rect
		r.width /= 2
		r.x = rect.x + rect.width - r.width
		self.time_rect = r
	}

	_status_ui_draw_box(state, ctx, rect)

	pos := rect_pos(rect)
	pos.y += rect.height / 2 - TINY_BUTTON_SIZE / 2
	pos.x += H_GAP

	// TODO: move these buttons into a context menu to not clutter the UI.
	// Draw action buttons.
	{
		btn :: draw_action_button
		G :: GAP / 2

		pos.x -= G
		pos.x += btn(state, ctx, &self.button_shuffle, .Shuffle, pos) + G
		pos.x += btn(state, ctx, &self.button_clear, .Trash, pos) + G
	}

	pos.x += GAP
	pos.y = rect.y + ctx.font_height
	pos.y += rect.height / 2 - ctx.font_height / 2

	// Draw number of songs.
	{
		count_str := fmt.tprint("♪", len(player.queue))
		ui.draw_text(ctx, count_str, pos, state.theme.gray)
	}

	// Draw time.
	{
		elapsed := player.queue_elapsed + player.elapsed
		duration := player.queue_duration
		time_str := _queue_status_ui_time(elapsed, duration)

		pos.x = rect.x + rect.width - H_GAP
		ui.draw_text(ctx, time_str, pos, state.theme.gray, align = .End)
	}
}

_queue_status_ui_time :: proc(elapsed, duration: Seconds) -> string {
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

_status_ui_set_offset :: proc(offset: f32) {
	if self.offset == offset do return
	ui.tween_play(&self.tween, self.offset, STATUS_REVEAL_ANIM_DURATION)
	self.offset = offset
}
_status_ui_set_queue_offset :: proc(offset: f32) {
	if self.queue_offset == offset do return
	ui.tween_play(&self.queue_tween, self.queue_offset, STATUS_REVEAL_ANIM_DURATION / 2)
	self.queue_offset = offset
}

status_ui_visible_height :: proc() -> i32 {
	return max(STATUS_MAX_HEIGHT - self.cur_offset - self.cur_queue_offset, 0)
}
