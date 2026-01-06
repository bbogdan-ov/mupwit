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

	albums: [dynamic]mpd.Album // let it leak
	albums_covers: [dynamic]raylib.Texture // let it leak

	camera := raylib.Camera2D {
		zoom = 1.0,
	}

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.BeginMode2D(camera)
		raylib.ClearBackground({20, 20, 20, 255})

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
				for &tex in albums_covers do raylib.UnloadTexture(tex)
				delete(albums)
				resize(&albums_covers, len(e.albums))

				albums = e.albums
				raylib.TraceLog(.INFO, "Received albums list (%d)", len(e.albums))

				for album, idx in e.albums {
					mpd.push_action(client, mpd.Action_Req_Cover{idx, album.first_song.uri})
				}
			case mpd.Event_Cover:
				tex := &albums_covers[e.id]
				assert(tex.id == 0)
				tex^ = raylib.LoadTextureFromImage(e.cover.image)
				raylib.UnloadImage(e.cover.image)
			}

			player_on_event(&player, client, &event)
		}
		mpd.free_events(client)

		camera.offset.y += raylib.GetMouseWheelMove() * 20

		if raylib.IsKeyPressed(.P) {
			mpd.push_action(client, mpd.Action_Play{})
		} else if raylib.IsKeyPressed(.O) {
			mpd.push_action(client, mpd.Action_Pause{})
		} else if raylib.IsKeyPressed(.A) {
			mpd.push_action(client, mpd.Action_Req_Albums{})
		}

		switch state {
		case .Connecting:
			raylib.DrawText("Connecting...", 4, 4, 20, raylib.WHITE)
		case .Ready:
			raylib.DrawText("Ready!", 4, 4, 20, raylib.WHITE)

			if status, ok := player.status.?; ok {
				if song, ok := player.song.?; ok {
					title_ := song.title.? or_else "<unknown>"
					artist_ := song.artist.? or_else "<unknown>"
					album_ := song.album.? or_else "<unknown>"
					title := strings.clone_to_cstring(title_, context.temp_allocator)
					artist := strings.clone_to_cstring(artist_, context.temp_allocator)
					album := strings.clone_to_cstring(album_, context.temp_allocator)

					raylib.DrawText(title, 4, 30, 20, raylib.WHITE)
					raylib.DrawText(artist, 4, 50, 20, raylib.WHITE)
					raylib.DrawText(album, 4, 70, 20, raylib.WHITE)

					sb := strings.builder_make()
					fmt.sbprint(&sb, status.elapsed)
					raylib.DrawText(strings.to_cstring(&sb), 4, 90, 20, raylib.WHITE)

					strings.builder_reset(&sb)
					fmt.sbprint(&sb, status.state)
					raylib.DrawText(strings.to_cstring(&sb), 4, 110, 20, raylib.WHITE)
				}
			}

			for album, idx in albums {
				title_ := album.title.? or_else "<unknown>"
				title := strings.clone_to_cstring(title_, context.temp_allocator)

				y := 130 + i32(idx) * 32

				if albums_covers[idx].id != 0 {
					tex := albums_covers[idx]
					source := raylib.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
					dest := raylib.Rectangle{200, f32(y), 64, 64}
					raylib.DrawTexturePro(tex, source, dest, {}, 0, raylib.WHITE)
				}
				raylib.DrawText(title, 4, y, 10, raylib.WHITE)
			}

		case .Error:
			raylib.DrawText("Error", 4, 4, 20, raylib.WHITE)
		}

		raylib.EndMode2D()

		x := i32(math.sin(raylib.GetTime() * 10) * 20) + 20
		raylib.DrawRectangle(x, 16, 32, 32, raylib.RED)

		raylib.EndDrawing()
		free_all(context.temp_allocator)
	}

	raylib.TraceLog(.INFO, "Bye")
}
