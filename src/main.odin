package mupwit

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

import "mpd"

main :: proc() {
	state: mpd.State = .Connecting

	client := mpd.connect()
	defer mpd.destroy(client)

	player := player_make()
	defer player_destroy(&player)

	rl.InitWindow(400, 600, "hey")
	defer rl.CloseWindow()

	rl.SetTargetFPS(120)

	albums: [dynamic]mpd.Album // let it leak
	albums_covers: [dynamic]rl.Texture // let it leak

	camera := rl.Camera2D {
		zoom = 1.0,
	}

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.BeginMode2D(camera)
		rl.ClearBackground({20, 20, 20, 255})

		events: for {
			event := mpd.pop_event(client)
			#partial switch &e in event {
			case nil:
				break events
			case mpd.Event_State_Changed:
				// TODO: display the error message if state is `.Error`
				state = e.state
			case mpd.Event_Albums:
				for &album in albums do mpd.album_destroy(&album)
				for &tex in albums_covers do rl.UnloadTexture(tex)
				delete(albums)
				resize(&albums_covers, len(e.albums))

				albums = e.albums
				rl.TraceLog(.INFO, "Received albums list (%d)", len(e.albums))

				for album, idx in e.albums {
					mpd.push_action(client, mpd.Action_Req_Cover{idx, album.first_song.uri})
				}
			case mpd.Event_Cover:
				tex := &albums_covers[e.id]
				assert(tex.id == 0)
				tex^ = rl.LoadTextureFromImage(e.cover.image)
				rl.UnloadImage(e.cover.image)
			}

			player_on_event(&player, client, &event)
		}
		mpd.free_events(client)

		camera.offset.y += rl.GetMouseWheelMove() * 20

		if rl.IsKeyPressed(.P) {
			mpd.push_action(client, mpd.Action_Play{})
		} else if rl.IsKeyPressed(.O) {
			mpd.push_action(client, mpd.Action_Pause{})
		} else if rl.IsKeyPressed(.A) {
			mpd.push_action(client, mpd.Action_Req_Albums{})
		}

		switch state {
		case .Connecting:
			rl.DrawText("Connecting...", 4, 4, 20, rl.WHITE)
		case .Ready:
			rl.DrawText("Ready!", 4, 4, 20, rl.WHITE)

			if status, ok := player.status.?; ok {
				if song, ok := player.song.?; ok {
					title_ := song.title.? or_else "<unknown>"
					artist_ := song.artist.? or_else "<unknown>"
					album_ := song.album.? or_else "<unknown>"
					title := strings.clone_to_cstring(title_, context.temp_allocator)
					artist := strings.clone_to_cstring(artist_, context.temp_allocator)
					album := strings.clone_to_cstring(album_, context.temp_allocator)

					rl.DrawText(title, 4, 30, 20, rl.WHITE)
					rl.DrawText(artist, 4, 50, 20, rl.WHITE)
					rl.DrawText(album, 4, 70, 20, rl.WHITE)

					sb := strings.builder_make()
					fmt.sbprint(&sb, status.elapsed)
					rl.DrawText(strings.to_cstring(&sb), 4, 90, 20, rl.WHITE)

					strings.builder_reset(&sb)
					fmt.sbprint(&sb, status.state)
					rl.DrawText(strings.to_cstring(&sb), 4, 110, 20, rl.WHITE)
				}
			}

			for album, idx in albums {
				title_ := album.title.? or_else "<unknown>"
				title := strings.clone_to_cstring(title_, context.temp_allocator)

				y := 130 + i32(idx) * 32

				if albums_covers[idx].id != 0 {
					tex := albums_covers[idx]
					source := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
					dest := rl.Rectangle{200, f32(y), 64, 64}
					rl.DrawTexturePro(tex, source, dest, {}, 0, rl.WHITE)
				}
				rl.DrawText(title, 4, y, 10, rl.WHITE)
			}

		case .Error:
			rl.DrawText("Error", 4, 4, 20, rl.WHITE)
		}

		rl.EndMode2D()

		x := i32(math.sin(rl.GetTime() * 10) * 20) + 20
		rl.DrawRectangle(x, 16, 32, 32, rl.RED)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	rl.TraceLog(.INFO, "Bye")
}
