package mupwit

import rl "vendor:raylib"

import "mpd"
import "pages"
import "ui"
import "wheel"

client_state: mpd.State = .Connecting
client: ^mpd.Client
player: wheel.Player

main :: proc() {
	client = mpd.connect()
	player = wheel.player_make()

	rl.InitWindow(ui.WINDOW_WIDTH, ui.WINDOW_HEIGHT, "MUPWIT")
	rl.SetTargetFPS(120)

	ui.assets_load()
	ui.state_init()

	for !rl.WindowShouldClose() {
		ui.state_frame_begin()

		update()
		draw()
	}

	wheel.player_destroy(&player)
	ui.state_destroy()
	ui.assets_destroy()
	rl.CloseWindow()

	mpd.close(client)

	rl.TraceLog(.INFO, "Bye")
}

update :: #force_inline proc() {
	// Handle incoming events
	events: for {
		event := mpd.pop_event(client)
		switch &e in event {
		case nil:
			break events
		case mpd.Event_State_Changed:
			client_state = e.state

		case mpd.Event_Status:
			wheel.player_on_status(&player, e.status)
		case mpd.Event_Status_And_Song:
			wheel.player_on_status_and_song(&player, e.status, e.song)

		case mpd.Event_Albums:
			for &a in e.albums do mpd.album_destroy(&a)
			delete(e.albums)

		case mpd.Event_Cover:
			mpd.cover_destroy(&e.cover)
		}
	}
}

draw_app :: #force_inline proc() {
	pages.player_draw(&player)
}

draw :: #force_inline proc() {
	rl.BeginDrawing()
	rl.ClearBackground(ui.BACKGROUND)

	switch client_state {
	case .Connecting:
		ui.draw_text("Connecting...", {}, ui.BLACK)
	case .Ready:
		draw_app()
	case .Error:
		ui.draw_text("Error!", {}, ui.BLACK)
	}

	rl.EndDrawing()
}
