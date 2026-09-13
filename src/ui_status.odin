package mupwit

import "core:fmt"
import "lib:ui"

@(private = "file")
status_ui: struct {
	button_play: ui.Button,
	slider:      ui.Slider,
}

status_ui_update :: proc() {
	if ui.button_update(&status_ui.button_play) {
		player_toggle_play()
	}

	if ui.slider_update(&status_ui.slider) {
		player_seek_percent(status_ui.slider.progress)
	}
}

status_ui_draw :: proc(ctx: ^ui.Context) {
	btn_play := &status_ui.button_play

	rect := ctx.screen
	rect.height = PLAYER_HEIGHT
	rect.y = ctx.screen.height - rect.height

	ui.draw_rect(ctx, rect, BACKGROUND)
	ui.draw_line_h(ctx, rect, GRAY)

	ui.begin_container(ctx, rect, GAP)

	// Draw play button.
	icon := icon_from_playstate(state.player.playstate)
	draw_icon_button(ctx, btn_play, icon, rect_pos(ctx.container), BLACK)

	{
		cont := ui.cut_left(ctx.container, btn_play.rect.width + GAP)
		cont.width -= GAP
		ui.begin_container(ctx, cont, 0)

		offset: Vec2
		offset.y = ctx.container.height / 2
		offset.y += -(ctx.font_height * 2 + ui.SLIDER_THICKNESS) / 2 + ctx.font_height

		// Draw song title and artist.
		song, has_song := player_cur_song()
		if has_song {
			pos := rect_pos(ctx.container) + offset
			pos.x += ui.draw_text(ctx, song.title, pos, BLACK).x
			pos.x += ui.draw_text(ctx, fmt.tprint(" -", song.artist), pos, GRAY).x
		}

		// Draw slider.
		{
			progress := state.player.elapsed / state.player.duration
			rect := ctx.container
			rect.height = ui.SLIDER_THICKNESS
			rect.y += offset.y + ctx.font_height
			ui.slider_draw(ctx, &status_ui.slider, progress, rect, BLACK, thumb = false)
		}
	}
}
