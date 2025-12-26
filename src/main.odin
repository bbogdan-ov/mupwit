package mupwit

import "core:fmt"
import "core:math"
import "vendor:raylib"

import "client"
import "loop"

main :: proc() {
	event_loop := loop.make()
	defer loop.destroy(event_loop)
	client.connect(event_loop)

	state: client.State = .Connecting

	raylib.InitWindow(256, 256, "hey")
	raylib.SetTargetFPS(60)

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		events: for {
			event := loop.pop_event(event_loop)
			switch e in event {
			case nil:
				break events
			case loop.Event_Client_Ready:
				state = .Ready
			case loop.Event_Client_Error:
				state = .Error
			case loop.Event_Song_Pos:
				fmt.print(e)
			}
		}

		if raylib.IsKeyPressed(.P) {
			loop.push_action(event_loop, loop.Action_Play{})
		} else if raylib.IsKeyPressed(.O) {
			loop.push_action(event_loop, loop.Action_Pause{})
		} else if raylib.IsKeyPressed(.SPACE) {
			loop.push_action(event_loop, loop.Action_Req_Status{})
		}

		x := cast(i32)(math.sin(raylib.GetTime() * 10) * 20)
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
