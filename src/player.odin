package mupwit

import "../lib/mpd"

Player :: struct #all_or_none {
	// Current playback status
	status: Maybe(mpd.Status),
	// Current song
	song:   Maybe(mpd.Song),
}

player: Player

player_init :: proc() {
	player = Player {
		status = nil,
		song   = nil,
	}
}
player_destroy :: proc() {
	if s, ok := &player.song.?; ok do mpd.song_destroy(s)
}

player_on_status :: proc(event: mpd.Event_Status) {
	player.status = event.status
}
player_on_status_and_song :: proc(event: mpd.Event_Status_And_Song) {
	player.status = event.status

	s, ok := &player.song.?
	if ok do mpd.song_destroy(s)
	player.song = event.song
}
