package mupwit

import "core:fmt"
import "core:log"
import "core:time"

import "../lib/mpd"
import "../lib/ui"

main :: proc() {
	// Initialize logger
	context.logger = log.Logger {
		procedure = logger_proc,
	}

	// Initialize window
	ui.window_init(WINDOW_TITLE, "mupwit", WINDOW_WIDTH, WINDOW_HEIGHT)
	load_assets()

	// Initialize other things
	client_state: mpd.State = .Connecting
	client := mpd.connect()

	player_init()
	defer player_destroy()
	queue_init()
	defer queue_destroy()

	queue_page := queue_page_create()

	// TODO: temporary
	mpd.send_action(client, mpd.Action_Req_Queue{})

	for !ui.window_should_close() {
		// Update

		// Handle incoming events
		events: for {
			event := mpd.recv_event(client)
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
				// TODO: consume all the received albums for now
				for &a in e.albums do mpd.album_destroy(&a)
				delete(e.albums)

			case mpd.Event_Queue:
				queue_on_queue(e)

			case mpd.Event_Cover:
				// TODO: consume all the received covers for now
				mpd.cover_destroy(&e.cover)
			}
		}

		// Draw
		ui.begin_frame(BACKGROUND)

		switch client_state {
		case .Connecting:
			draw_normal_text("Connecting...", {}, BLACK)
		case .Ready:
			queue_page_draw(&queue_page)
			player_panel_draw(client)
		case .Error:
			draw_normal_text("Error!", {}, BLACK)
		}

		ui.end_frame()
	}

	mpd.send_action(client, mpd.Action_Close{})

	assets_destroy()
	ui.window_close()

	mpd.close(client)
}

logger_proc :: proc(
	data: rawptr,
	level: log.Level,
	text: string,
	options: log.Options,
	location := #caller_location,
) {
	fmt.print("\x1b[37m")

	h, m, s, nanos := time.precise_clock(time.now())
	fmt.printf("%02d:%02d:%02d.%03d ", h, m, s, nanos / 1_000_000)

	switch level {
	case .Debug:
		fmt.print("\x1b[37mDEBUG:\x1b[0m ")
	case .Info:
		fmt.print("\x1b[94mINFO:\x1b[0m ")
	case .Warning:
		// TODO: log relative path to the file
		fmt.printf("(%s:%d) ", location.file_path, location.line)
		fmt.print("\x1b[93mWARN:\x1b[0m ")
	case .Error:
		// TODO: log relative path to the file
		fmt.printf("(%s:%d) ", location.file_path, location.line)
		fmt.print("\x1b[91mERROR:\x1b[0m ")
	case .Fatal:
		// TODO: log relative path to the file
		fmt.printf("(%s:%d) ", location.file_path, location.line)
		fmt.print("\x1b[91;7mFATAL:\x1b[0m ")
	}

	fmt.println(text)
}
