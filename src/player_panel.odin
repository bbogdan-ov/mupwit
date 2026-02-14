package mupwit

import "../lib/mpd"
import "../lib/ui"

PLAYER_PANEL_HEIGHT :: ICON_BUTTON_SIZE + GAP * 2

player_panel_draw :: proc() {
	container := ui.Rect {
		0,
		ui.window.height - PLAYER_PANEL_HEIGHT,
		ui.window.width,
		PLAYER_PANEL_HEIGHT,
	}
	offset := ui.Point{container.x, container.y} + GAP

	// Draw panel background and border
	{
		ui.draw_rect(container, BACKGROUND)
		border := container
		border.height = 1
		ui.draw_rect(border, GRAY)
	}

	ui.begin_text_truncate(offset.x, container.width - GAP * 3)
	defer ui.end_text_truncate()

	// Draw play/pause button
	{
		icon: Icon = .Play
		if status, ok := player.status.?; ok {
			if status.state == .Play do icon = .Pause
		}

		pressed := draw_icon_button(icon, offset)
		offset.x += ICON_BUTTON_SIZE + GAP

		if pressed do mpd.send_action(client, mpd.Action_Toggle{})
	}

	// Draw song info
	if cur_song, ok := player.song.?; ok {
		title := cur_song.title.? or_else UNKNOWN
		artist := cur_song.artist.? or_else UNKNOWN

		orig_offset_x := offset.x
		offset.x += draw_normal_text(title, offset).x
		offset.x += draw_normal_text(" - ", offset, GRAY).x
		offset.y += draw_normal_text(artist, offset, GRAY).y
		offset.x = orig_offset_x
	}

	// Draw progress
	{
		rect := ui.Rect {
			offset.x,
			container.y + container.height - GAP - 4 * 2,
			container.width - ICON_BUTTON_SIZE - GAP * 4,
			4,
		}

		draw_box(.Normal, rect)

		if status, ok := player.status.?; ok {
			width := rect.width * (f32(status.elapsed) / f32(status.duration))
			ui.draw_rect({rect.x + 1, rect.y + 1, width, 2}, BLACK)
		}
	}
}
