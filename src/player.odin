package mupwit

import "mpd"

Player :: struct {
	// Current playback status
	status: Maybe(mpd.Status),
	// Current song
	song:   Maybe(mpd.Song),
}

player_make :: proc() -> Player {
	return Player{status = nil}
}

player_on_event :: proc(player: ^Player, client: ^mpd.Client, event: ^mpd.Event) {
	#partial switch e in event {
	case mpd.Event_Status:
		player.status = e.status

		event^ = nil
	case mpd.Event_Song:
		mpd.song_destroy(&player.song.? or_else nil)
		player.song = e.song

		event^ = nil
	case mpd.Event_Song_And_Status:
		player.status = e.status

		mpd.song_destroy(&player.song.? or_else nil)
		player.song = e.song

		event^ = nil
	}
}
