package mupwit

import "client"
import "core:fmt"

Player :: struct {
	status: Maybe(client.Status),
}

player_make :: proc() -> Player {
	return Player{status = nil}
}

player_on_event :: proc(player: ^Player, event: ^client.Event) {
	#partial switch e in event {
	case client.Event_Status:
		player.status = e.status
		fmt.println("Player updated")
		fmt.println(player.status)
		event^ = nil
	}
}
