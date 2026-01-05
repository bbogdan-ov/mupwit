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
	case mpd.Event_Status_And_Song:
		player.status = e.status
		_set_song(player, e.song)

		event^ = nil
	}
}

@(private)
_set_song :: proc(player: ^Player, song: Maybe(mpd.Song)) {
	s, ok := &player.song.?
	if ok do mpd.song_destroy(s)

	player.song = song
}
