package mupwit

import "core:math"
import "vendor:raylib"

import "client"
import loop_ "loop"

main :: proc() {
	loop := loop_.make()
	defer loop_.destroy(loop)
	client.connect(loop)

	status: client.Status = .Connecting

	raylib.InitWindow(256, 256, "hey")
	raylib.SetTargetFPS(60)

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		events: for {
			event := loop_.pop_event(loop)
			switch e in event {
			case nil:
				break events
			case loop_.Event_Client_Ready:
				status = .Ready
			case loop_.Event_Client_Error:
				status = .Error
			}
		}

		if raylib.IsKeyPressed(.P) {
			loop_.push_action(loop, loop_.Action_Play{})
		} else if raylib.IsKeyPressed(.O) {
			loop_.push_action(loop, loop_.Action_Pause{})
		}

		x := cast(i32)(math.sin(raylib.GetTime() * 10) * 20)
		raylib.DrawRectangle(x, 16, 32, 32, raylib.RED)

		switch status {
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
