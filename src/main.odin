package mupwit

import rl "vendor:raylib"

import "mpd"
import "ui"

client_state: mpd.State = .Connecting
client: ^mpd.Client
player: Player

main :: proc() {
	client = mpd.connect()
	player = player_make()

	rl.InitWindow(ui.WINDOW_WIDTH, ui.WINDOW_HEIGHT, "MUPWIT")
	rl.SetTargetFPS(120)

	ui.assets_load()

	for !rl.WindowShouldClose() {
		update()
		draw()
	}

	player_destroy()
	mpd.destroy(client)
	ui.assets_destroy()

	rl.CloseWindow()

	rl.TraceLog(.INFO, "Bye")
}

update :: #force_inline proc() {
	// Handle events
	events: for {
		event := mpd.pop_event(client)
		switch &e in event {
		case nil:
			break events
		case mpd.Event_State_Changed:
			client_state = e.state

		case mpd.Event_Status:
			player_on_status(e.status)
		case mpd.Event_Status_And_Song:
			player_on_status_and_song(e.status, e.song)

		case mpd.Event_Albums:
			for &a in e.albums do mpd.album_destroy(&a)
			delete(e.albums)

		case mpd.Event_Cover:
			mpd.cover_destroy(&e.cover)
		}
	}
}

draw_app :: #force_inline proc() {
}

draw :: #force_inline proc() {
	rl.BeginDrawing()
	rl.ClearBackground(ui.BACKGROUND)

	switch client_state {
	case .Connecting:
		ui.draw_normal_text("Connecting...", {}, ui.BLACK)
	case .Ready:
		draw_app()
	case .Error:
		ui.draw_normal_text("Error!", {}, ui.BLACK)
	}

	rl.EndDrawing()
}
