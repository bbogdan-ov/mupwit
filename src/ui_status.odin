//
// Playback status panel that sits at the bottom of the screen and displays the
// currently playing song and elapsed time within it.
//

package mupwit

import "core:fmt"

import "lib:ui"

@(private = "file")
self: struct {
	button_play: ui.Button,
	slider:      ui.Slider,
	tween:       ui.Tween(f32),
	reveal:      f32,
}

status_ui_update :: proc(state: ^State, dt: Seconds) {
	ui.tween_update(&self.tween, dt)

	if state.screen == .Player {
		_status_ui_set_reveal(0)
		return
	}

	_status_ui_set_reveal(1)

	player := &state.player

	if ui.button_update(&self.button_play) {
		player_toggle_play(player)
	}

	if ui.slider_update(&self.slider) {
		player_seek_percent(player, self.slider.progress)
	}
}

status_ui_draw :: proc(state: ^State, ctx: ^ui.Context) {
	p := ui.tween_ease(&self.tween, self.reveal, .Cubic_Out)
	offset := i32(STATUS_HEIGHT * (1 - p))
	if offset >= STATUS_HEIGHT do return

	btn_play := &self.button_play

	rect := ui.state.view
	rect.height = STATUS_HEIGHT
	rect.y = ui.state.view.height - rect.height
	rect.y += offset

	ui.draw_rect(ctx, rect, BACKGROUND)
	ui.draw_line_h(ctx, rect, GRAY)

	ui.begin_box(ctx, rect, GAP)

	// Draw play button.
	icon := icon_from_playstate(state.player.playstate)
	draw_icon_button(state, ctx, btn_play, icon, rect_pos(ctx.box), BLACK)

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
			pos.x += ui.draw_text(ctx, song.title, pos, BLACK).x
			pos.x += ui.draw_text(ctx, fmt.tprint(" -", song.artist), pos, GRAY).x
		}

		// Draw slider.
		{
			rect := ctx.box
			rect.height = ui.SLIDER_THICKNESS
			rect.y += offset.y + ctx.font_height

			progress := player_progress(&state.player)
			ui.slider_draw(ctx, &self.slider, progress, rect, BLACK, GRAY, thumb = false)
		}
	}
}

_status_ui_set_reveal :: proc(reveal: f32) {
	if self.reveal == reveal do return
	ui.tween_play(&self.tween, self.reveal, STATUS_REVEAL_ANIM_DURATION)
	self.reveal = reveal
}
