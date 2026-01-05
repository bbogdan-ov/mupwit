package mupwit

import "core:fmt"
import "core:math"
import "core:strings"
import "vendor:raylib"

import "mpd"

main :: proc() {
	state: mpd.State = .Connecting

	client := mpd.connect()
	defer mpd.destroy(client)

	player := player_make()
	defer player_destroy(&player)

	raylib.InitWindow(400, 600, "hey")
	defer raylib.CloseWindow()

	raylib.SetTargetFPS(120)

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		events: for {
			event := mpd.pop_event(client)
			#partial switch &e in event {
			case nil:
				break events
			case mpd.Event_State_Changed:
				// TODO: display the error message if state is `.Error`
				state = e.state
			}

			player_on_event(&player, client, &event)
		}
		mpd.free_events(client)

		if raylib.IsKeyPressed(.P) {
			mpd.push_action(client, mpd.Action_Play{})
		} else if raylib.IsKeyPressed(.O) {
			mpd.push_action(client, mpd.Action_Pause{})
		}

		x := i32(math.sin(raylib.GetTime() * 10) * 20)
		raylib.DrawRectangle(x, 16, 32, 32, raylib.RED)

		switch state {
		case .Connecting:
			raylib.DrawText("Connecting...", 4, 4, 20, raylib.WHITE)
		case .Ready:
			raylib.DrawText("Ready!", 4, 4, 20, raylib.WHITE)

			if status, ok := player.status.?; ok {
				if song, ok := player.song.?; ok {
					title: string = song.title.? or_else "<unknown>"
					artist: string = song.artist.? or_else "<unknown>"
					album: string = song.album.? or_else "<unknown>"

					raylib.DrawText(strings.clone_to_cstring(title), 4, 30, 20, raylib.WHITE)
					raylib.DrawText(strings.clone_to_cstring(artist), 4, 50, 20, raylib.WHITE)
					raylib.DrawText(strings.clone_to_cstring(album), 4, 70, 20, raylib.WHITE)

					sb := strings.builder_make()
					fmt.sbprint(&sb, status.elapsed)
					raylib.DrawText(strings.to_cstring(&sb), 4, 90, 20, raylib.WHITE)

					strings.builder_reset(&sb)
					fmt.sbprint(&sb, status.state)
					raylib.DrawText(strings.to_cstring(&sb), 4, 110, 20, raylib.WHITE)
				}
			}

		case .Error:
			raylib.DrawText("Error", 4, 4, 20, raylib.WHITE)
		}

		raylib.EndDrawing()
	}

	raylib.TraceLog(.INFO, "Bye")
}
