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
	button_play:  ui.Button,
	slider:       ui.Slider,
	tween:        ui.Tween(f32),
	queue_tween:  ui.Tween(f32),
	reveal:       f32,
	queue_reveal: f32,
	time_mode:    Status_Time_Mode,
	queue_rect:   Rect,
}

status_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.tween_update(&self.tween, dt)
	ui.tween_update(&self.queue_tween, dt)

	if state.screen == .Player {
		_status_ui_set_reveal(0)
		return
	}
	_status_ui_set_reveal(1)

	if state.screen == .Queue {
		_status_ui_set_queue_reveal(1)
	} else {
		_status_ui_set_queue_reveal(0)
	}

	player := &state.player

	if ui.button_update(&self.button_play) {
		player_toggle_play(player)
	}

	if ui.slider_update(&self.slider) {
		player_seek_percent(player, self.slider.progress)
	}

	if self.queue_reveal == 1 && ui.is_pointer_inside(self.queue_rect) {
		ui.set_cursor(.Pointer)

		if ui.is_clicked(.Left) {
			self.time_mode = enum_rotate_variant(self.time_mode, 1)
		} else if ui.is_clicked(.Right) {
			self.time_mode = enum_rotate_variant(self.time_mode, -1)
		}
	}
}

status_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	MAX_OFFSET :: STATUS_HEIGHT + QUEUE_STATUS_HEIGHT

	p := ui.tween_ease(&self.tween, self.reveal, .Sine_In_Out)
	offset := i32(MAX_OFFSET * (1 - p))
	if offset >= MAX_OFFSET do return

	btn_play := &self.button_play

	rect := ui.state.view
	rect.height = STATUS_HEIGHT
	rect.y = ui.state.view.height - rect.height
	rect.y += offset

	{
		p := ui.tween_ease(&self.queue_tween, self.queue_reveal, .Sine_In_Out)

		r := rect
		r.height = QUEUE_STATUS_HEIGHT
		r.y -= r.height
		r.y += i32(f32(r.height) * (1 - p))
		_queue_status_ui_draw(state, ctx, r)
	}

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
		song, has_song := player_cur_song(&state.player)
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

_queue_status_ui_draw :: proc(state: ^State, ctx: ^ui.Context, rect: Rect) {
	player := &state.player

	_status_ui_draw_box(state, ctx, rect)
	self.queue_rect = rect

	H_GAP :: GAP * 2

	count_str := fmt.tprint("♪", len(player.queue))

	pos := rect_pos(rect)
	pos.y += ctx.font_height + rect.height / 2 - ctx.font_height / 2
	pos.x += H_GAP
	ui.draw_text(ctx, count_str, pos, state.theme.gray)

	time_str: string
	elapsed := player.queue_elapsed + player.elapsed

	switch self.time_mode {
	case .Time_Left:
		left := elapsed - player.queue_duration
		time_str = fmt.tprint(mpd.Seconds(left))
	case .Elapsed:
		time_str = fmt.tprint(mpd.Seconds(elapsed))
	case .Elapsed_Duration:
		time_str = fmt.tprint(mpd.Seconds(elapsed), '/', mpd.Seconds(player.queue_duration))
	}

	pos.x = rect.x + rect.width - H_GAP
	ui.draw_text(ctx, time_str, pos, state.theme.gray, align = .End)
}

_status_ui_draw_box :: proc(state: ^State, cr: ^cairo.cairo_t, rect: Rect) {
	ui.draw_rect(cr, rect, state.theme.background)
	ui.draw_line_h(cr, rect, state.theme.gray)
}

_status_ui_set_reveal :: proc(reveal: f32) {
	if self.reveal == reveal do return
	ui.tween_play(&self.tween, self.reveal, STATUS_REVEAL_ANIM_DURATION)
	self.reveal = reveal
}
_status_ui_set_queue_reveal :: proc(reveal: f32) {
	if self.queue_reveal == reveal do return
	ui.tween_play(&self.queue_tween, self.queue_reveal, STATUS_REVEAL_ANIM_DURATION / 2)
	self.queue_reveal = reveal
}
