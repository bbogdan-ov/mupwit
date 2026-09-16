package mupwit

import "core:fmt"
import "lib:ui"

@(private = "file")
self: struct {
	button_play: ui.Button,
	slider:      ui.Slider,
}

status_ui_update :: proc() {
	if ui.button_update(&self.button_play) {
		player_toggle_play()
	}

	if ui.slider_update(&self.slider) {
		player_seek_percent(self.slider.progress)
	}
}

status_ui_draw :: proc(ctx: ^ui.Context) {
	btn_play := &self.button_play

	rect := ui.state.view
	rect.height = PLAYER_HEIGHT
	rect.y = ui.state.view.height - rect.height

	ui.draw_rect(ctx, rect, BACKGROUND)
	ui.draw_line_h(ctx, rect, GRAY)

	ui.begin_box(ctx, rect, GAP)

	// Draw play button.
	icon := icon_from_playstate(state.player.playstate)
	draw_icon_button(ctx, btn_play, icon, rect_pos(ctx.box), BLACK)

	{
		box := ui.pad_l(ctx.box, btn_play.rect.width + GAP)
		box.width -= GAP
		ui.begin_box(ctx, box, 0)

		offset: Vec2
		offset.y = ctx.box.height / 2
		offset.y += -(ctx.font_height * 2 + ui.SLIDER_THICKNESS) / 2 + ctx.font_height

		// Draw song title and artist.
		song, has_song := player_cur_song()
		if has_song {
			pos := rect_pos(ctx.box) + offset
			pos.x += ui.draw_text(ctx, song.title, pos, BLACK).x
			pos.x += ui.draw_text(ctx, fmt.tprint(" -", song.artist), pos, GRAY).x
		}

		// Draw slider.
		{
			progress := state.player.elapsed / state.player.duration
			rect := ctx.box
			rect.height = ui.SLIDER_THICKNESS
			rect.y += offset.y + ctx.font_height
			ui.slider_draw(ctx, &self.slider, progress, rect, BLACK, thumb = false)
		}
	}
}
