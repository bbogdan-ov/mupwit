package mupwit

import "client"

Player :: struct {
	// Current playback status
	status: Maybe(client.Status),
	// Current song
	song:   Maybe(client.Song),
}

player_make :: proc() -> Player {
	return Player{status = nil}
}

player_on_event :: proc(player: ^Player, loop: ^client.Event_Loop, event: ^client.Event) {
	#partial switch e in event {
	case client.Event_Status:
		player.status = e.status

		event^ = nil
	case client.Event_Song:
		client.song_destroy(&player.song.? or_else nil)
		player.song = e.song

		event^ = nil
	case client.Event_Song_And_Status:
		player.status = e.status

		client.song_destroy(&player.song.? or_else nil)
		player.song = e.song

		event^ = nil
	}
}
