package mupwit

import "core:math"
import "core:strings"
import "vendor:raylib"

import "mpd"

main :: proc() {
	state: mpd.State = .Connecting

	client := mpd.connect()
	player := player_make()

	raylib.InitWindow(400, 600, "hey")
	raylib.SetTargetFPS(60)

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

			if song, ok := player.song.?; ok {
				title: string = song.title.? or_else "<unknown>"
				artist: string = song.artist.? or_else "<unknown>"
				album: string = song.album.? or_else "<unknown>"

				raylib.DrawText(strings.clone_to_cstring(title), 4, 30, 20, raylib.WHITE)
				raylib.DrawText(strings.clone_to_cstring(artist), 4, 50, 20, raylib.WHITE)
				raylib.DrawText(strings.clone_to_cstring(album), 4, 70, 20, raylib.WHITE)
			}

		case .Error:
			raylib.DrawText("Error", 4, 4, 20, raylib.WHITE)
		}

		raylib.EndDrawing()
	}

	raylib.TraceLog(.INFO, "Bye")
}
