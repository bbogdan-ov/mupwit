package mupwit

import "core:fmt"
import "core:math"
import "vendor:raylib"

import "client"

main :: proc() {
	event_loop := client.loop_make()
	defer client.loop_destroy(event_loop)

	state: client.State = .Connecting

	client.connect(event_loop)

	raylib.InitWindow(400, 600, "hey")
	raylib.SetTargetFPS(60)

	textures: [dynamic]raylib.Texture

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		events: for {
			event := client.loop_pop_event(event_loop)
			switch &e in event {
			case nil:
				break events
			case client.Event_State_Changed:
				// TODO: display the error message if state is `.Error`
				state = e.state
			case client.Event_Status:
				fmt.println(e.status)
			case client.Event_Cover:
				defer client.cover_destroy(&e.cover)

				tex := raylib.LoadTextureFromImage(e.cover.image)
				append(&textures, tex)

				raylib.TraceLog(.INFO, "Received album cover image")
			}
		}

		if raylib.IsKeyPressed(.P) {
			client.loop_push_action(event_loop, client.Action_Play{})
		} else if raylib.IsKeyPressed(.O) {
			client.loop_push_action(event_loop, client.Action_Pause{})
		} else if raylib.IsKeyPressed(.SPACE) {
			client.loop_push_action(event_loop, client.Action_Req_Status{})
		} else if raylib.IsKeyPressed(.C) {
			uris := []string {
				`"Alec Normal/Named After You/004 Prom Missed Me.mp3"`,
				`"Tame Impala/The Slow Rush/008 Lost In Yesterday.mp3"`,
				`"Radiohead/OK Computer/007 Fitter Happier.mp3"`,
				`"Radiohead/The Bends/008 My Iron Lung.mp3"`,
				`"Radiohead/Knives Out/003 Fog.mp3"`,
				`"Radiohead/In Rainbows/007 Reckoner.mp3"`,
				`"Whitey/THE LIGHT AT THE END OF THE TUNNEL IS A TRAIN/014 THE AWFUL TRUTH.mp3"`,
				`"Radiohead/The Daily Mail ___ Staircase/002 Staircase.mp3"`,
				`"Whitey/LOST SONGS VOL. 3: WRONG DESTINATION/004 A GIRL LIKE YOU.mp3"`,
				`"Radiohead/OK Computer OKNOTOK 1997-2017/011 How I Made My Millions.mp3"`,
				`"Jack Stauber/Viator/015 Gretchen.mp3"`,
			}

			for uri in uris {
				client.loop_push_action(event_loop, client.Action_Req_Cover{uri})
			}
		}

		S :: 80
		N :: 4

		for tex, idx in textures {
			source := raylib.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			dest := raylib.Rectangle{0, 0, S, S}

			dest.x = f32(idx % N) * S
			dest.y = f32(idx / N) * S

			raylib.DrawTexturePro(tex, source, dest, {}, 0, raylib.WHITE)
		}

		x := i32(math.sin(raylib.GetTime() * 10) * 20)
		raylib.DrawRectangle(x, 16, 32, 32, raylib.RED)

		switch state {
		case .Connecting:
			raylib.DrawText("Connecting...", 4, 4, 20, raylib.WHITE)
		case .Ready:
			raylib.DrawText("Ready!", 4, 4, 20, raylib.WHITE)
		case .Error:
			raylib.DrawText("Error", 4, 4, 20, raylib.WHITE)
		}


		raylib.EndDrawing()
	}

	raylib.TraceLog(.INFO, "Bye")
}
