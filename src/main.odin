package mupwit

import "mpd"
import "ui"

import "../build/assets"

main :: proc() {
	client_state: mpd.State = .Connecting
	client := mpd.connect()
	player := player_make()

	ui.window_init()
	load_assets()

	for !ui.window_should_close() {
		// Update

		// Handle incoming events
		events: for {
			event := mpd.pop_event(client)
			switch &e in event {
			case nil:
				break events
			case mpd.Event_State_Changed:
				client_state = e.state

			case mpd.Event_Status:
				player_on_status(&player, e.status)
			case mpd.Event_Status_And_Song:
				player_on_status_and_song(&player, e.status, e.song)

			case mpd.Event_Albums:
				for &a in e.albums do mpd.album_destroy(&a)
				delete(e.albums)

			case mpd.Event_Cover:
				mpd.cover_destroy(&e.cover)
			}
		}

		// Draw
		ui.begin_frame(ui.BACKGROUND)

		switch client_state {
		case .Connecting:
			ui.draw_text("Connecting...", {}, ui.BLACK)
		case .Ready:
			player_page_draw(&player)
		case .Error:
			ui.draw_text("Error!", {}, ui.BLACK)
		}

		ui.end_frame()
	}

	ui.assets_destroy()
	ui.window_close()
}

load_assets :: proc() {
	assert(ui.window.ready)

	ui.assets = ui.Assets {
		normal_font   = assets.font_load_kaplimono_regular(),
		italic_font   = assets.font_load_kapli_italic(),
		boxes         = assets.image_load_boxes(),
		icons         = assets.image_load_icons(),
		dummy_artwork = assets.image_load_dummy_artwork(),
	}
}
