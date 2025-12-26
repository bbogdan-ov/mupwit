package mupwit

import "core:fmt"
import "core:math"
import "vendor:raylib"

import "client"

main :: proc() {
	event_loop := client.loop_make()
	defer client.loop_destroy(event_loop)

	client.connect(event_loop)

	state: client.State = .Connecting

	raylib.InitWindow(256, 256, "hey")
	raylib.SetTargetFPS(60)

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		events: for {
			event := client.loop_pop_event(event_loop)
			switch e in event {
			case nil:
				break events
			case client.Event_State_Changed:
				state = e.state
			case client.Event_Status:
				fmt.println(e.status)
			}
		}

		if raylib.IsKeyPressed(.P) {
			client.loop_push_action(event_loop, client.Action_Play{})
		} else if raylib.IsKeyPressed(.O) {
			client.loop_push_action(event_loop, client.Action_Pause{})
		} else if raylib.IsKeyPressed(.SPACE) {
			client.loop_push_action(event_loop, client.Action_Req_Status{})
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
